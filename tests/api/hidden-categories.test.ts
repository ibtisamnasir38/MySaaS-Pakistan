import request from 'supertest'
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import prisma from '../../backend/src/lib/prisma'
import app from '../../backend/src/app'

describe('Hidden categories stay unlisted but reachable by direct link', () => {
  const slug = `hc-${Date.now()}`
  const host = `${slug}.localhost:3000`

  let tenantId: string
  let visibleCategoryId: string
  let hiddenCategoryId: string
  const hiddenCategorySlug = `hidden-cat-${Date.now()}`
  const visibleCategorySlug = `visible-cat-${Date.now()}`
  let hiddenOnlyProductSlug: string
  let visibleProductSlug: string

  beforeAll(async () => {
    const tenant = await prisma.tenant.create({ data: { name: 'Hidden Categories Tenant', slug } })
    tenantId = tenant.id

    const visibleCategory = await prisma.category.create({
      data: { tenantId, title: 'Visible Category', slug: visibleCategorySlug, isHidden: false }
    })
    visibleCategoryId = visibleCategory.id

    const hiddenCategory = await prisma.category.create({
      data: { tenantId, title: 'Hidden Category', slug: hiddenCategorySlug, isHidden: true }
    })
    hiddenCategoryId = hiddenCategory.id

    hiddenOnlyProductSlug = `prod-hidden-cat-${Date.now()}`
    await prisma.product.create({
      data: {
        tenantId,
        title: 'Pens',
        slug: hiddenOnlyProductSlug,
        price: 500,
        stock: 10,
        isActive: true,
        categoryId: hiddenCategoryId
      }
    })

    visibleProductSlug = `prod-visible-cat-${Date.now()}`
    await prisma.product.create({
      data: {
        tenantId,
        title: 'Notebook',
        slug: visibleProductSlug,
        price: 900,
        stock: 10,
        isActive: true,
        categoryId: visibleCategoryId
      }
    })
  })

  afterAll(async () => {
    await prisma.product.deleteMany({ where: { tenantId } })
    await prisma.category.deleteMany({ where: { tenantId } })
    await prisma.tenantSubscription.deleteMany({ where: { tenantId } })
    await prisma.tenantDomain.deleteMany({ where: { tenantId } })
    await prisma.tenant.deleteMany({ where: { id: tenantId } })
  })

  it('excludes the hidden category from the public categories list', async () => {
    const res = await request(app).get('/api/categories').set('Host', host)

    expect(res.status).toBe(200)
    expect(res.body.some((c: any) => c.id === hiddenCategoryId)).toBe(false)
    expect(res.body.some((c: any) => c.id === visibleCategoryId)).toBe(true)
  })

  it('still resolves the hidden category by direct slug lookup', async () => {
    const res = await request(app).get(`/api/categories/${hiddenCategorySlug}`).set('Host', host)

    expect(res.status).toBe(200)
    expect(res.body.id).toBe(hiddenCategoryId)
  })

  it('excludes products whose only category is hidden from the general listing', async () => {
    const res = await request(app).get('/api/products').set('Host', host)

    expect(res.status).toBe(200)
    expect(res.body.some((p: any) => p.slug === hiddenOnlyProductSlug)).toBe(false)
    expect(res.body.some((p: any) => p.slug === visibleProductSlug)).toBe(true)
  })

  it('still returns the hidden category product when fetched by that category', async () => {
    const res = await request(app)
      .get('/api/products')
      .query({ category: hiddenCategoryId })
      .set('Host', host)

    expect(res.status).toBe(200)
    expect(res.body.some((p: any) => p.slug === hiddenOnlyProductSlug)).toBe(true)
  })
})
