import { Router } from 'express'
import { CategoriesController } from './categories.controller'

const router = Router()
const controller = new CategoriesController()

// GET /categories - Public categories listing
router.get('/', controller.listPublicCategories)

// GET /categories/:slug - Public category detail (ignores hidden flag for direct-link access)
router.get('/:slug', controller.getPublicCategoryBySlug)

export default router
