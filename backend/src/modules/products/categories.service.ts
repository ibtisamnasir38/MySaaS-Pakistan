import prisma from '../../lib/prisma'

const normalizeImageUrl = (value: unknown): string | null | undefined => {
    if (value === undefined) return undefined
    if (value === null) return null
    if (typeof value !== 'string') throw new Error('Invalid image')

    const trimmed = value.trim()
    if (!trimmed) return null
    const isHttpUrl = /^https?:\/\//i.test(trimmed)
    const isRelativeUpload = /^\/uploads\//i.test(trimmed)

    let pathname: string
    if (isHttpUrl) {
        try {
            const url = new URL(trimmed)
            pathname = url.pathname.toLowerCase()
        } catch {
            throw new Error('Invalid image')
        }
    } else if (isRelativeUpload) {
        // Normalize relative upload path
        pathname = trimmed.toLowerCase()
    } else {
        throw new Error('Invalid image')
    }

    if (!pathname.endsWith('.png')) {
        throw new Error('Invalid image type')
    }

    return trimmed
}

export class CategoriesService {
    private orderCategoriesByHierarchy(categories: any[]): any[] {
        const byParent = new Map<string | null, any[]>()
        for (const category of categories) {
            const parentKey = category.parentId ?? null
            const group = byParent.get(parentKey) ?? []
            group.push(category)
            byParent.set(parentKey, group)
        }

        for (const group of byParent.values()) {
            group.sort((a, b) => String(a.title || '').localeCompare(String(b.title || '')))
        }

        const ordered: any[] = []
        const seen = new Set<string>()
        const walk = (node: any, depth = 0) => {
            if (!node?.id || seen.has(node.id)) return
            seen.add(node.id)
            ordered.push({ ...node, depth })
            const children = byParent.get(node.id) || []
            for (const child of children) {
                walk(child, depth + 1)
            }
        }

        for (const root of byParent.get(null) || []) {
            walk(root, 0)
        }

        // Defensive fallback for orphaned rows.
        for (const category of categories) {
            if (!seen.has(category.id)) {
                walk(category, 0)
            }
        }

        return ordered
    }

    private mapCategory(category: any): any {
        const rawCount = category?._count ?? {}
        const productsCount =
            Number(rawCount.productLinks ?? 0) > 0
                ? Number(rawCount.productLinks ?? 0)
                : Number(rawCount.products ?? 0)
        const parentTitle = category?.parent?.title ?? null
        const displayTitle = parentTitle ? `${parentTitle} / ${category.title}` : category.title

        return {
            ...category,
            parentTitle,
            isSubcategory: Boolean(category?.parentId),
            displayTitle,
            _count: {
                ...rawCount,
                products: productsCount,
                subcategories: Number(rawCount.children ?? 0)
            }
        }
    }

    private async resolveParentCategoryId(
        tenantId: string,
        value: unknown,
        currentCategoryId?: string
    ): Promise<string | null | undefined> {
        if (value === undefined) return undefined
        if (value === null || value === '') return null
        if (typeof value !== 'string') throw new Error('Invalid parent category')

        const parent = await prisma.category.findFirst({
            where: { tenantId, id: value },
            select: { id: true, parentId: true }
        })
        if (!parent) throw new Error('Invalid parent category')
        if (currentCategoryId && parent.id === currentCategoryId) {
            throw new Error('Category cannot be its own parent')
        }

        // Ensure the new parent is not a descendant of the current category.
        if (currentCategoryId) {
            let cursor = parent.parentId
            let guard = 0
            while (cursor && guard < 100) {
                if (cursor === currentCategoryId) {
                    throw new Error('Category hierarchy cycle detected')
                }
                const next = await prisma.category.findFirst({
                    where: { tenantId, id: cursor },
                    select: { parentId: true }
                })
                cursor = next?.parentId ?? null
                guard++
            }
        }

        return parent.id
    }

    async listAdmin(tenantId: string, sortBy?: string, sortOrder?: 'asc' | 'desc') {
        const sortableFields: Record<string, boolean> = {
            createdAt: true,
            title: true,
            slug: true,
            products: true
        }

        const orderBy = (() => {
            if (sortBy && sortableFields[sortBy]) {
                if (sortBy === 'products') {
                    return { productLinks: { _count: (sortOrder === 'asc' ? 'asc' : 'desc') as const } }
                }
                return { [sortBy]: (sortOrder === 'asc' ? 'asc' : 'desc') as const }
            }
            return { createdAt: 'desc' as const }
        })()

        const categories = await prisma.category.findMany({
            where: { tenantId },
            include: {
                parent: { select: { id: true, title: true, slug: true } },
                _count: { select: { products: true, productLinks: true, children: true } }
            },
            orderBy
        })

        return categories.map((category) => this.mapCategory(category))
    }

    async listPublic(tenantId: string) {
        const categories = await prisma.category.findMany({
            where: { tenantId, isHidden: false },
            include: {
                parent: { select: { id: true, title: true, slug: true } },
                _count: { select: { products: true, productLinks: true, children: true } }
            },
            orderBy: [{ parentId: 'asc' }, { title: 'asc' }]
        })

        const mapped = categories.map((category) => this.mapCategory(category))
        return this.orderCategoriesByHierarchy(mapped)
    }

    async getPublicCategoryBySlug(tenantId: string, slug: string) {
        // Deliberately ignores isHidden so a hidden category is still reachable
        // by visiting its direct URL, even though it's excluded from listPublic().
        const category = await prisma.category.findFirst({
            where: { tenantId, slug },
            include: {
                parent: { select: { id: true, title: true, slug: true } },
                _count: { select: { products: true, productLinks: true, children: true } }
            }
        })

        return category ? this.mapCategory(category) : null
    }

    async isSlugAvailable(tenantId: string, slug: string, excludeCategoryId?: string) {
        const existing = await prisma.category.findFirst({
            where: {
                tenantId,
                slug,
                ...(excludeCategoryId ? { NOT: { id: excludeCategoryId } } : {})
            },
            select: { id: true }
        })

        return !existing
    }

    async createCategory(
        tenantId: string,
        data: { id?: unknown; title?: string; slug?: string; imageUrl?: unknown; parentId?: unknown; isHidden?: unknown }
    ) {
        if (!data.title || !data.slug) {
            throw new Error('Title and Slug are required')
        }

        const clientId = typeof data.id === 'string' ? data.id.trim() : ''
        if (data.id !== undefined && (!clientId || clientId.length > 100)) {
            throw new Error('Invalid id')
        }
        if (clientId) {
            const existingById = await prisma.category.findUnique({
                where: { id: clientId },
                select: { tenantId: true }
            })
            if (existingById?.tenantId === tenantId) return await this.getCategory(tenantId, clientId)
            if (existingById) throw new Error('Invalid id')
        }

        const existing = await prisma.category.findFirst({
            where: { tenantId, slug: data.slug }
        })
        if (existing) {
            throw new Error('Category with this slug already exists')
        }

        const imageUrl = normalizeImageUrl(data.imageUrl)
        const parentId = await this.resolveParentCategoryId(tenantId, data.parentId)

        const created = await prisma.category.create({
            data: {
                ...(clientId ? { id: clientId } : {}),
                tenantId,
                title: data.title,
                slug: data.slug,
                imageUrl: imageUrl ?? null,
                parentId: parentId ?? null,
                isHidden: Boolean(data.isHidden)
            },
            include: {
                parent: { select: { id: true, title: true, slug: true } },
                _count: { select: { products: true, productLinks: true, children: true } }
            }
        })

        return this.mapCategory(created)
    }

    async updateCategory(
        tenantId: string,
        categoryId: string,
        data: { title?: string; slug?: string; imageUrl?: unknown; parentId?: unknown; isHidden?: unknown }
    ) {
        const category = await prisma.category.findFirst({
            where: { id: categoryId, tenantId }
        })
        if (!category) {
            throw new Error('Category not found')
        }

        if (data.slug && data.slug !== category.slug) {
            const slugExists = await prisma.category.findFirst({
                where: { tenantId, slug: data.slug, NOT: { id: categoryId } }
            })
            if (slugExists) {
                throw new Error('Category with this slug already exists')
            }
        }

        const imageUrl = normalizeImageUrl(data.imageUrl)
        const parentId = await this.resolveParentCategoryId(tenantId, data.parentId, categoryId)

        const updateResult = await prisma.category.updateMany({
            where: { id: categoryId, tenantId },
            data: {
                title: data.title ?? category.title,
                slug: data.slug ?? category.slug,
                imageUrl: imageUrl,
                parentId,
                isHidden: data.isHidden === undefined ? category.isHidden : Boolean(data.isHidden)
            }
        })

        if (updateResult.count === 0) {
            throw new Error('Category not found')
        }

        const updated = await prisma.category.findFirst({
            where: { id: categoryId, tenantId },
            include: {
                parent: { select: { id: true, title: true, slug: true } },
                _count: { select: { products: true, productLinks: true, children: true } }
            }
        })

        return updated ? this.mapCategory(updated) : null
    }

    async getCategory(tenantId: string, categoryId: string) {
        const category = await prisma.category.findFirst({
            where: { id: categoryId, tenantId },
            include: {
                parent: { select: { id: true, title: true, slug: true } },
                _count: { select: { products: true, productLinks: true, children: true } }
            }
        })

        return category ? this.mapCategory(category) : null
    }

    async deleteCategory(tenantId: string, categoryId: string) {
        const category = await prisma.category.findFirst({
            where: { id: categoryId, tenantId },
            include: {
                _count: { select: { products: true, productLinks: true, children: true } }
            }
        })

        if (!category) {
            throw new Error('Category not found')
        }

        if (category._count.children > 0) {
            const err: any = new Error('HAS_CHILDREN')
            err.statusCode = 409
            err.statusMessage = 'HAS_CHILDREN'
            throw err
        }

        if (category._count.products > 0 || category._count.productLinks > 0) {
            const err: any = new Error('HAS_PRODUCTS')
            err.statusCode = 409
            err.statusMessage = 'HAS_PRODUCTS'
            throw err
        }

        await prisma.category.deleteMany({
            where: { id: categoryId, tenantId }
        })

        return true
    }
}
