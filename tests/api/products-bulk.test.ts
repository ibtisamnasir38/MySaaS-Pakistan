import request from 'supertest'
import AdmZip from 'adm-zip'
import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import prisma from '../../backend/src/lib/prisma'
import app from '../../backend/src/app'
import { signAccessToken } from '../../backend/src/lib/jwt'

// Minimal valid 1x1 PNG, reused to exercise the real image-upload pipeline (sharp optimizeImage).
const createTestPng = () =>
    Buffer.from([
        0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
        0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4, 0x89,
        0x00, 0x00, 0x00, 0x0a, 0x49, 0x44, 0x41, 0x54,
        0x78, 0x9c, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01,
        0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44,
        0xae, 0x42, 0x60, 0x82
    ])

describe('Admin products bulk ops', () => {
    const slugA = `bulk-a-${Date.now()}`
    const hostA = `${slugA}.localhost:3000`
    let tenantAId: string
    let adminAToken: string
    let categoryAId: string
    let categoryBId: string
    let productAId: string
    let deleteAProduct1Id: string
    let deleteAProduct2Id: string

    const slugB = `bulk-b-${Date.now()}`
    const hostB = `${slugB}.localhost:3000`
    let tenantBId: string
    let adminBToken: string

    beforeAll(async () => {
        const tenantA = await prisma.tenant.create({ data: { name: 'Bulk A', slug: slugA } })
        tenantAId = tenantA.id
        const adminA = await prisma.user.create({
            data: { tenantId: tenantAId, email: `admin-${slugA}@example.com`, role: 'admin', passwordHash: 'x' }
        })
        adminAToken = signAccessToken({
            userId: adminA.id,
            email: adminA.email,
            role: adminA.role,
            tenantId: adminA.tenantId
        })

        const cat = await prisma.category.create({
            data: { tenantId: tenantAId, title: 'Cat A', slug: `cat-a-${Date.now()}` }
        })
        categoryAId = cat.id

        const catB = await prisma.category.create({
            data: { tenantId: tenantAId, title: 'Cat B', slug: `cat-b-${Date.now()}` }
        })
        categoryBId = catB.id

        const product = await prisma.product.create({
            data: {
                tenantId: tenantAId,
                title: 'Bulk Product',
                slug: `bulk-product-${Date.now()}`,
                price: 100,
                stock: 1,
                isActive: true,
                categoryId: categoryAId
            }
        })
        productAId = product.id

        await prisma.productVariant.create({
            data: {
                tenantId: tenantAId,
                productId: productAId,
                sku: `BULK-${Date.now()}`,
                price: 100,
                stock: 1,
                reserved: 0,
                safetyStock: 0,
                trackInventory: true,
                isActive: true
            }
        })

        const toDelete1 = await prisma.product.create({
            data: {
                tenantId: tenantAId,
                title: 'Bulk Delete A1',
                slug: `bulk-delete-a1-${Date.now()}`,
                price: 10,
                stock: 1,
                isActive: true
            }
        })
        deleteAProduct1Id = toDelete1.id

        const toDelete2 = await prisma.product.create({
            data: {
                tenantId: tenantAId,
                title: 'Bulk Delete A2',
                slug: `bulk-delete-a2-${Date.now()}`,
                price: 20,
                stock: 1,
                isActive: true
            }
        })
        deleteAProduct2Id = toDelete2.id

        const tenantB = await prisma.tenant.create({ data: { name: 'Bulk B', slug: slugB } })
        tenantBId = tenantB.id
        const adminB = await prisma.user.create({
            data: { tenantId: tenantBId, email: `admin-${slugB}@example.com`, role: 'admin', passwordHash: 'x' }
        })
        adminBToken = signAccessToken({
            userId: adminB.id,
            email: adminB.email,
            role: adminB.role,
            tenantId: adminB.tenantId
        })
    })

    afterAll(async () => {
        await prisma.inventoryMovement.deleteMany({ where: { tenantId: tenantAId } })
        await prisma.productVariantImage.deleteMany({ where: { tenantId: tenantAId } })
        await prisma.productVariantOptionValue.deleteMany({ where: { tenantId: tenantAId } })
        await prisma.productVariant.deleteMany({ where: { tenantId: tenantAId } })
        await prisma.productOptionValue.deleteMany({ where: { tenantId: tenantAId } })
        await prisma.productOption.deleteMany({ where: { tenantId: tenantAId } })
        await prisma.productImage.deleteMany({ where: { tenantId: tenantAId } })
        await prisma.productBundleDeal.deleteMany({ where: { tenantId: tenantAId } })
        await prisma.productCategory.deleteMany({ where: { tenantId: tenantAId } })
        await prisma.product.deleteMany({ where: { tenantId: tenantAId } })
        await prisma.category.deleteMany({ where: { tenantId: tenantAId } })
        await prisma.user.deleteMany({ where: { tenantId: tenantAId } })
        await prisma.tenant.deleteMany({ where: { id: tenantAId } })

        await prisma.inventoryMovement.deleteMany({ where: { tenantId: tenantBId } })
        await prisma.productVariantImage.deleteMany({ where: { tenantId: tenantBId } })
        await prisma.productVariantOptionValue.deleteMany({ where: { tenantId: tenantBId } })
        await prisma.productVariant.deleteMany({ where: { tenantId: tenantBId } })
        await prisma.productOptionValue.deleteMany({ where: { tenantId: tenantBId } })
        await prisma.productOption.deleteMany({ where: { tenantId: tenantBId } })
        await prisma.productImage.deleteMany({ where: { tenantId: tenantBId } })
        await prisma.productBundleDeal.deleteMany({ where: { tenantId: tenantBId } })
        await prisma.productCategory.deleteMany({ where: { tenantId: tenantBId } })
        await prisma.product.deleteMany({ where: { tenantId: tenantBId } })
        await prisma.category.deleteMany({ where: { tenantId: tenantBId } })
        await prisma.user.deleteMany({ where: { tenantId: tenantBId } })
        await prisma.tenant.deleteMany({ where: { id: tenantBId } })
    })

    it('exports products CSV for tenant', async () => {
        const res = await request(app)
            .get('/api/admin/products/export.csv')
            .set('X-Forwarded-Host', hostA)
            .set('Authorization', `Bearer ${adminAToken}`)

        expect(res.status).toBe(200)
        expect(String(res.headers['content-type'])).toContain('text/csv')
        expect(res.text).toContain('id,title,slug')
        expect(res.text).toContain('Bulk Product')
    })

    it('rejects cross-tenant admin token on tenant host', async () => {
        const res = await request(app)
            .get('/api/admin/products/export.csv')
            .set('X-Forwarded-Host', hostA)
            .set('Authorization', `Bearer ${adminBToken}`)

        expect(res.status).toBe(403)
    })

    it('imports CSV but ignores stock updates after creation', async () => {
        const csv = [
            'id,slug,title,price,stock,isActive,categoryId',
            `${productAId},,Bulk Product Updated,150,7,true,${categoryAId}`
        ].join('\n')

        const res = await request(app)
            .post('/api/admin/products/import.csv')
            .set('X-Forwarded-Host', hostA)
            .set('Authorization', `Bearer ${adminAToken}`)
            .attach('file', Buffer.from(csv, 'utf8'), { filename: 'products.csv', contentType: 'text/csv' })

        expect(res.status).toBe(200)
        expect(res.body.updated).toBe(1)
        expect(res.body.warnings?.[0]?.message).toMatch(/stock is system-managed/i)

        const refreshed = await prisma.product.findFirst({ where: { tenantId: tenantAId, id: productAId } })
        expect(refreshed?.title).toBe('Bulk Product Updated')
        expect(String(refreshed?.price)).toBe('150')

        const variant = await prisma.productVariant.findFirst({
            where: { tenantId: tenantAId, productId: productAId, optionValues: { none: {} } }
        })
        expect(variant?.stock).toBe(1)

        const move = await prisma.inventoryMovement.findFirst({
            where: { tenantId: tenantAId, variantId: variant!.id, reason: 'bulk_import' },
            orderBy: { createdAt: 'desc' }
        })
        expect(move).toBeNull()
    })

    it('imports multi-category mappings from categoryIds column', async () => {
        const slug = `bulk-multi-cat-${Date.now()}`
        const csv = [
            'slug,title,price,categoryIds',
            `${slug},Multi Category Product,120,${categoryAId}|${categoryBId}`
        ].join('\n')

        const res = await request(app)
            .post('/api/admin/products/import.csv')
            .set('X-Forwarded-Host', hostA)
            .set('Authorization', `Bearer ${adminAToken}`)
            .attach('file', Buffer.from(csv, 'utf8'), { filename: 'products.csv', contentType: 'text/csv' })

        expect(res.status).toBe(200)
        expect(res.body.created).toBe(1)
        expect(res.body.errors?.length || 0).toBe(0)

        const created = await prisma.product.findFirst({
            where: { tenantId: tenantAId, slug },
            select: { id: true, categoryId: true }
        })
        expect(created?.categoryId).toBe(categoryAId)

        const links = await prisma.productCategory.findMany({
            where: { tenantId: tenantAId, productId: created!.id },
            select: { categoryId: true }
        })
        expect(links.map((row) => row.categoryId)).toEqual(expect.arrayContaining([categoryAId, categoryBId]))
    })

    it('imports a categorized product into a different tenant instead of erroring on the source tenant category id', async () => {
        // Simulates migrating a catalog: export from tenant A (product has a category), then
        // import that same archive into tenant B, which has no category matching tenant A's id/slug.
        const exportRes = await request(app)
            .get(`/api/admin/products/export.zip?ids=${productAId}`)
            .set('X-Forwarded-Host', hostA)
            .set('Authorization', `Bearer ${adminAToken}`)
            .buffer(true)
            .parse((response, callback) => {
                const chunks: Buffer[] = []
                response.on('data', (chunk: Buffer) => chunks.push(chunk))
                response.on('end', () => callback(null, Buffer.concat(chunks)))
            })
        expect(exportRes.status).toBe(200)

        const sourceProduct = await prisma.product.findFirst({ where: { tenantId: tenantAId, id: productAId } })

        const importRes = await request(app)
            .post('/api/admin/products/import.zip')
            .set('X-Forwarded-Host', hostB)
            .set('Authorization', `Bearer ${adminBToken}`)
            .attach('file', exportRes.body as Buffer, { filename: 'archive.zip', contentType: 'application/zip' })

        expect(importRes.status).toBe(200)
        expect(importRes.body.errors?.length || 0).toBe(0)
        expect(importRes.body.created).toBe(1)
        expect(
            (importRes.body.warnings ?? []).some((w: any) => /Category not found in this store/i.test(w.message))
        ).toBe(true)

        const created = await prisma.product.findFirst({ where: { tenantId: tenantBId, slug: sourceProduct!.slug } })
        expect(created).toBeTruthy()
        expect(created?.categoryId).toBeNull()
    })

    it('imports images and normalizes tenant-scoped upload links', async () => {
        const prevPublicUrl = process.env.S3_PUBLIC_URL
        const prevPublicBucket = process.env.S3_PUBLIC_BUCKET_NAME
        process.env.S3_PUBLIC_URL = 'https://nbg1.your-objectstorage.com'
        process.env.S3_PUBLIC_BUCKET_NAME = 'swekly-public'

        const slug = `import-img-${Date.now()}`
        const csv = [
            'slug,title,price,images',
            [
                slug,
                'Imported With Images',
                '9.99',
                [
                    'a.jpg',
                    `/uploads/${tenantBId}/b.jpg`,
                    `uploads/${tenantBId}/c.jpg`,
                    `public/uploads/${tenantBId}/d.jpg`,
                    `https://example.com/remote.jpg`,
                    `https://old-host.example/uploads/${tenantBId}/e.jpg`
                ].join('|')
            ].join(',')
        ].join('\n')

        const res = await request(app)
            .post('/api/admin/products/import.csv')
            .set('X-Forwarded-Host', hostA)
            .set('Authorization', `Bearer ${adminAToken}`)
            .attach('file', Buffer.from(csv, 'utf8'), { filename: 'products.csv', contentType: 'text/csv' })

        expect(res.status).toBe(200)
        expect(res.body.created).toBe(1)
        expect(res.body.errors?.length || 0).toBe(0)

        const created = await prisma.product.findFirst({ where: { tenantId: tenantAId, slug } })
        expect(created).toBeTruthy()

        const images = (created as any)?.images as string[]
        expect(images).toContain(`https://nbg1.your-objectstorage.com/swekly-public/tenants/${tenantAId}/public/a.jpg`)
        expect(images).toContain(`/uploads/${tenantAId}/b.jpg`)
        expect(images).toContain(`/uploads/${tenantAId}/c.jpg`)
        expect(images).toContain(`/uploads/${tenantAId}/d.jpg`)
        expect(images).toContain('https://example.com/remote.jpg')
        expect(images).toContain(`/uploads/${tenantAId}/e.jpg`)

        // Never persist cross-tenant upload paths.
        expect(images.some((u) => u.includes(`/uploads/${tenantBId}/`))).toBe(false)

        process.env.S3_PUBLIC_URL = prevPublicUrl
        process.env.S3_PUBLIC_BUCKET_NAME = prevPublicBucket
    })

    it('returns actionable messages for unsupported columns', async () => {
        const csv = [
            'slug,name_i18n,description_i18n,price,sale_price',
            'p-1,"{\\"ar\\":\\"x\\"}","{\\"ar\\":\\"y\\"}",10,9'
        ].join('\n')

        const res = await request(app)
            .post('/api/admin/products/import.csv')
            .set('X-Forwarded-Host', hostA)
            .set('Authorization', `Bearer ${adminAToken}`)
            .attach('file', Buffer.from(csv, 'utf8'), { filename: 'products.csv', contentType: 'text/csv' })

        expect(res.status).toBe(200)
        expect(res.body.errors?.length).toBe(1)
        expect(res.body.errors?.[0]?.message).toMatch(/Missing title for create/i)

        const warningsText = (res.body.warnings ?? []).map((w: any) => String(w.message)).join('\n')
        expect(warningsText).toMatch(/Ignoring unsupported columns/i)
        expect(warningsText).toMatch(/name_i18n/i)
        expect(warningsText).toMatch(/description_i18n/i)
    })

    it('exports a ZIP archive containing products.csv', async () => {
        const res = await request(app)
            .get('/api/admin/products/export.zip')
            .set('X-Forwarded-Host', hostA)
            .set('Authorization', `Bearer ${adminAToken}`)
            .buffer(true)
            .parse((response, callback) => {
                const chunks: Buffer[] = []
                response.on('data', (chunk: Buffer) => chunks.push(chunk))
                response.on('end', () => callback(null, Buffer.concat(chunks)))
            })

        expect(res.status).toBe(200)
        expect(String(res.headers['content-type'])).toContain('application/zip')

        const zip = new AdmZip(res.body as Buffer)
        const csvEntry = zip.getEntries().find((e) => e.entryName === 'products.csv')
        expect(csvEntry).toBeTruthy()

        const csvText = csvEntry!.getData().toString('utf8')
        expect(csvText).toContain('id,title,slug')
        expect(csvText).toContain('Bulk Product Updated')
    })

    it('rejects cross-tenant admin token for archive export', async () => {
        const res = await request(app)
            .get('/api/admin/products/export.zip')
            .set('X-Forwarded-Host', hostA)
            .set('Authorization', `Bearer ${adminBToken}`)

        expect(res.status).toBe(403)
    })

    it('imports a ZIP archive, uploading bundled images and creating the product', async () => {
        const slug = `zip-import-${Date.now()}`
        const csv = [
            'slug,title,price,images',
            `${slug},Zip Imported Product,49.99,images/${slug}.png`
        ].join('\n')

        const zip = new AdmZip()
        zip.addFile('products.csv', Buffer.from(csv, 'utf8'))
        zip.addFile(`images/${slug}.png`, createTestPng())

        const res = await request(app)
            .post('/api/admin/products/import.zip')
            .set('X-Forwarded-Host', hostA)
            .set('Authorization', `Bearer ${adminAToken}`)
            .attach('file', zip.toBuffer(), { filename: 'archive.zip', contentType: 'application/zip' })

        expect(res.status).toBe(200)
        expect(res.body.errors?.length || 0).toBe(0)
        expect(res.body.created).toBe(1)

        const created = await prisma.product.findFirst({ where: { tenantId: tenantAId, slug } })
        expect(created).toBeTruthy()

        const images = (created as any)?.images as string[]
        expect(images?.length).toBe(1)
        // The bundled zip-relative reference must have been replaced by a real, tenant-scoped upload URL.
        expect(images[0]).not.toBe(`images/${slug}.png`)
        expect(images[0]).toContain(tenantAId)
    })

    it('rejects non-ZIP uploads on the archive import endpoint', async () => {
        const res = await request(app)
            .post('/api/admin/products/import.zip')
            .set('X-Forwarded-Host', hostA)
            .set('Authorization', `Bearer ${adminAToken}`)
            .attach('file', Buffer.from('id,title\n', 'utf8'), { filename: 'not-a-zip.csv', contentType: 'text/csv' })

        expect(res.status).toBe(400)
    })

    const parseNdjson = (text: string): any[] =>
        text
            .split('\n')
            .map((line) => line.trim())
            .filter(Boolean)
            .map((line) => JSON.parse(line))

    it('streams export progress before the final archive payload', async () => {
        const res = await request(app)
            .get('/api/admin/products/export.zip/stream')
            .set('X-Forwarded-Host', hostA)
            .set('Authorization', `Bearer ${adminAToken}`)
            .buffer(true)
            .parse((response, callback) => {
                let text = ''
                response.on('data', (chunk: Buffer) => { text += chunk.toString('utf8') })
                response.on('end', () => callback(null, text))
            })

        expect(res.status).toBe(200)
        expect(String(res.headers['content-type'])).toContain('application/x-ndjson')

        const events = parseNdjson(res.body as unknown as string)
        expect(events.some((e) => e.type === 'progress')).toBe(true)
        const done = events.find((e) => e.type === 'done')
        expect(done).toBeTruthy()
        expect(done.filename).toBe('products-archive.zip')

        const zip = new AdmZip(Buffer.from(done.dataBase64, 'base64'))
        expect(zip.getEntries().some((e) => e.entryName === 'products.csv')).toBe(true)
    })

    it('streams import progress and a final summary for a ZIP archive', async () => {
        const slug = `zip-stream-import-${Date.now()}`
        const csv = ['slug,title,price,images', `${slug},Zip Stream Product,29.99,images/${slug}.png`].join('\n')

        const zip = new AdmZip()
        zip.addFile('products.csv', Buffer.from(csv, 'utf8'))
        zip.addFile(`images/${slug}.png`, createTestPng())

        const res = await request(app)
            .post('/api/admin/products/import.zip/stream')
            .set('X-Forwarded-Host', hostA)
            .set('Authorization', `Bearer ${adminAToken}`)
            .attach('file', zip.toBuffer(), { filename: 'archive.zip', contentType: 'application/zip' })
            .buffer(true)
            .parse((response, callback) => {
                let text = ''
                response.on('data', (chunk: Buffer) => { text += chunk.toString('utf8') })
                response.on('end', () => callback(null, text))
            })

        expect(res.status).toBe(200)
        const events = parseNdjson(res.body as unknown as string)
        expect(events.some((e) => e.type === 'progress' && e.phase === 'images')).toBe(true)
        expect(events.some((e) => e.type === 'progress' && e.phase === 'rows')).toBe(true)

        const done = events.find((e) => e.type === 'done')
        expect(done).toBeTruthy()
        expect(done.summary.created).toBe(1)

        const created = await prisma.product.findFirst({ where: { tenantId: tenantAId, slug } })
        expect(created).toBeTruthy()
    })

    it('reports granular progress across many products so large catalogs do not look frozen', async () => {
        const batchSlug = `scale-${Date.now()}`
        const batchIds: string[] = []
        for (let i = 0; i < 25; i++) {
            const p = await prisma.product.create({
                data: {
                    tenantId: tenantAId,
                    title: `Scale Product ${i}`,
                    slug: `${batchSlug}-${i}`,
                    price: 10,
                    stock: 1,
                    isActive: true
                }
            })
            batchIds.push(p.id)
        }

        const res = await request(app)
            .get(`/api/admin/products/export.zip/stream?ids=${batchIds.join(',')}`)
            .set('X-Forwarded-Host', hostA)
            .set('Authorization', `Bearer ${adminAToken}`)
            .buffer(true)
            .parse((response, callback) => {
                let text = ''
                response.on('data', (chunk: Buffer) => { text += chunk.toString('utf8') })
                response.on('end', () => callback(null, text))
            })

        expect(res.status).toBe(200)
        const events = parseNdjson(res.body as unknown as string)
        const progressEvents = events.filter((e) => e.type === 'progress')

        // More than a single jump straight to 100% — the UI needs several updates to render
        // a moving progress bar instead of appearing stuck.
        expect(progressEvents.length).toBeGreaterThan(5)
        expect(progressEvents[progressEvents.length - 1].processed).toBe(25)
        expect(progressEvents.every((e) => e.total === 25)).toBe(true)

        const done = events.find((e) => e.type === 'done')
        expect(done).toBeTruthy()
        const zip = new AdmZip(Buffer.from(done.dataBase64, 'base64'))
        const csvText = zip.getEntries().find((e) => e.entryName === 'products.csv')!.getData().toString('utf8')
        expect((csvText.match(/Scale Product/g) || []).length).toBe(25)

        await prisma.product.deleteMany({ where: { tenantId: tenantAId, id: { in: batchIds } } })
    })

    it('bulk patches products and duplicates selected product', async () => {
        const patch = await request(app)
            .patch('/api/admin/products/bulk')
            .set('X-Forwarded-Host', hostA)
            .set('Authorization', `Bearer ${adminAToken}`)
            .send({
                ids: [productAId],
                data: { isActive: false, price: '199' },
                options: { propagatePriceToVariants: true }
            })

        expect(patch.status).toBe(200)

        const dup = await request(app)
            .post(`/api/admin/products/${productAId}/duplicate`)
            .set('X-Forwarded-Host', hostA)
            .set('Authorization', `Bearer ${adminAToken}`)
            .send({})

        expect(dup.status).toBe(200)
        expect(dup.body.id).toBeDefined()
        expect(dup.body.id).not.toBe(productAId)
        expect(dup.body.isActive).toBe(false)
        expect(String(dup.body.slug)).toContain('copy')

        const newVariants = await prisma.productVariant.findMany({ where: { tenantId: tenantAId, productId: dup.body.id } })
        expect(newVariants.length).toBeGreaterThan(0)
    })

    it('blocks bulk patch stock updates', async () => {
        const res = await request(app)
            .patch('/api/admin/products/bulk')
            .set('X-Forwarded-Host', hostA)
            .set('Authorization', `Bearer ${adminAToken}`)
            .send({
                ids: [productAId],
                data: { stock: 9 }
            })

        expect(res.status).toBe(400)
        expect(res.body?.statusMessage).toMatch(/system-managed/i)
    })

    it('bulk deletes products and enforces tenancy', async () => {
        const del = await request(app)
            .delete('/api/admin/products/bulk')
            .set('X-Forwarded-Host', hostA)
            .set('Authorization', `Bearer ${adminAToken}`)
            .send({ ids: [deleteAProduct1Id, deleteAProduct2Id] })

        expect(del.status).toBe(200)
        expect(del.body?.success).toBe(true)
        expect(del.body?.deletedCount).toBe(2)

        const remaining = await prisma.product.findMany({
            where: { tenantId: tenantAId, id: { in: [deleteAProduct1Id, deleteAProduct2Id] } },
            select: { id: true }
        })
        expect(remaining.length).toBe(0)

        const cross = await request(app)
            .delete('/api/admin/products/bulk')
            .set('X-Forwarded-Host', hostB)
            .set('Authorization', `Bearer ${adminBToken}`)
            .send({ ids: [productAId] })

        expect(cross.status).toBe(404)

        const stillThere = await prisma.product.findFirst({ where: { tenantId: tenantAId, id: productAId }, select: { id: true } })
        expect(stillThere?.id).toBe(productAId)
    })
})
