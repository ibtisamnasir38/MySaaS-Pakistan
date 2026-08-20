<script setup lang="ts">
import { categoryTemplates, resolveTemplateKey } from '~/components/storefront/templates/registry'
import type { TemplateKey } from '~/components/storefront/templates/registry'

const route = useRoute()
const slug = route.params.slug as string
const storeSettings = useState<any>('storeSettings')
const templateKey = computed<TemplateKey>(() => resolveTemplateKey(storeSettings.value?.templateKey))

type Category = {
  id: string
  title: string
  displayTitle?: string
  slug: string
  imageUrl?: string | null
}
type Product = {
  id: string
  title: string
  slug: string
  description?: string | null
  price: string | number
  stock: number
  isActive: boolean
  categoryId?: string | null
  categoryIds?: string[]
  categories?: Array<{ id: string; title: string; slug: string }>
}

const categoryUrl = useTenantApiUrl(`/api/categories/${encodeURIComponent(slug)}`)

let fetchedCategory: Category | null = null
try {
  fetchedCategory = await $fetch(categoryUrl, { headers: useTenantApiHeaders() }) as Category
} catch {
  throw createError({ statusCode: 404, statusMessage: 'Category not found' })
}
if (!fetchedCategory) {
  throw createError({ statusCode: 404, statusMessage: 'Category not found' })
}
const category = {
  ...fetchedCategory,
  title: fetchedCategory.title
} as Category

const productsUrl = useTenantApiUrl('/api/products')

const products = ref<Product[]>([])
try {
  products.value = await $fetch(productsUrl, { headers: useTenantApiHeaders(), query: { category: category.id } }) as Product[]
} catch {
  throw createError({ statusCode: 500, statusMessage: 'Failed to load products' })
}

const categoryProducts = computed(() =>
  (products.value || []).map((product) => ({
    ...product,
    // Keep legacy template filters working (`p.categoryId === activeCategory.id`).
    categoryId: category.id
  }))
)

useTenantSeo({
  title: `${category.title}`,
  description: `Browse products in ${category.title}.`
})

definePageMeta({
  middleware: 'tenant-only',
  layout: 'store'
})

const ActiveTemplate = computed(() => categoryTemplates[templateKey.value])
</script>

<template>
  <component
    :is="ActiveTemplate"
    :category="category"
    :products="categoryProducts"
  />
</template>
