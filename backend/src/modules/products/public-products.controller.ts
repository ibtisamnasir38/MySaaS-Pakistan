import type { Request, Response } from 'express'
import { PublicProductsService } from './public-products.service'

export class PublicProductsController {
    constructor(private service = new PublicProductsService()) {}

    async list(req: Request, res: Response) {
        const tenant = req.tenant
        if (!tenant) {
            return res.status(404).json({ statusCode: 404, statusMessage: 'Tenant not found' })
        }

        try {
            const search = typeof req.query.q === 'string' ? req.query.q : undefined
            const categoryId = typeof req.query.category === 'string' ? req.query.category : undefined
            const products = await this.service.listProducts(tenant.id, search, categoryId)
            res.json(products)
        } catch (error) {
            console.error('Public products list error:', error)
            res.status(500).json({ statusCode: 500, message: 'Internal Server Error' })
        }
    }

    async getBySlug(req: Request, res: Response) {
        const tenant = req.tenant
        const { slug } = req.params
        if (!tenant) {
            return res.status(404).json({ statusCode: 404, statusMessage: 'Tenant not found' })
        }

        try {
            const product = await this.service.getProductBySlug(tenant.id, slug as string)
            if (!product) {
                return res.status(404).json({ statusCode: 404, statusMessage: 'Product not found' })
            }
            res.json(product)
        } catch (error) {
            console.error('Public product detail error:', error)
            res.status(500).json({ statusCode: 500, message: 'Internal Server Error' })
        }
    }
}

