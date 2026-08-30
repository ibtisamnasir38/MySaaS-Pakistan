import { Prisma, ShipmentProvider, ShipmentStatus, type PrismaClient, type Shipment } from '@prisma/client'
import prisma from '../../lib/prisma'
import { MaystroProvider } from './providers/maystro.provider'
import { YalidineProvider, isSystemicYalidineFailure } from './providers/yalidine.provider'
import { SelfDeliveryProvider } from './providers/self.provider'
import { PakistanProvider } from './providers/pakistan.provider'
import { DELIVERY_PROVIDER_CATALOG, getProviderCatalogItem } from './catalog'
import { MaystroOrderService } from './maystro/maystro-order.service'
import { MaystroWebhookService } from './maystro/maystro-webhook.service'
import { MaystroLocationService } from './maystro/maystro-location.service'
import { MaystroIntegrationError } from './maystro/maystro.errors'
import { normalizeLocationName } from './shared/normalize-location-name'
import { moneyToCents, centsToMoney } from '../../../../shared/pricing/bundle-pricing'
import { OrdersService } from '../orders/orders.service'
import type {
    CreateShipmentInput,
    ProviderCommune,
    ProviderPickupPoint,
    QuoteOption,
    QuoteRequest,
    TrackingEvent,
    DeliveryProvider
} from './types'

export type CarrierRateRow = {
    wilayaCode: string
    carrierPrice: number | null
    currency: string
    serviceLevel?: string
}

/** Carrier price lists change on the order of months, so a day is comfortably fresh. */
const CARRIER_RATE_CACHE_TTL_MS = 24 * 60 * 60 * 1000

/**
 * Hard ceiling on one rate-table build. A carrier that stops responding costs a
 * request timeout plus retries for every remaining wilaya; without this an operator's
 * click hangs for many minutes instead of coming back with a reason.
 */
const CARRIER_RATE_BUILD_BUDGET_MS = 60_000

/** Failures in a row before concluding the carrier is down rather than one wilaya. */
const CARRIER_RATE_FAILURE_STREAK = 5

type ProviderApiConfig = {
    // Maystro Orders Management API
    apiToken?: string
    storeId?: string
    inventorySyncEnabled?: boolean

    // Yalidine
    apiId?: string
    yalidineApiToken?: string
    originWilayaId?: string
    originWilayaName?: string
}

const isRecord = (value: unknown): value is Record<string, unknown> =>
    typeof value === 'object' && value !== null && !Array.isArray(value)

const normalizeOrderDeliveryMode = (value: unknown): 'home' | 'office' | undefined => {
    const raw = typeof value === 'string' ? value.trim().toLowerCase() : ''
    if (raw === 'home') return 'home'
    if (raw === 'pickup' || raw === 'desk' || raw === 'office') return 'office'
    return undefined
}

const computeOrderTotalWithShipping = (order: { totalAmount?: unknown; totalWithShippingAmount?: unknown; shippingAmount?: unknown }) => {
    const storedTotalWithShippingRaw = order.totalWithShippingAmount
    const storedTotalWithShipping =
        storedTotalWithShippingRaw == null ? NaN : Number(storedTotalWithShippingRaw)
    if (Number.isFinite(storedTotalWithShipping)) return storedTotalWithShipping

    const orderTotalRaw = order.totalAmount
    const orderTotal = Number.isFinite(Number(orderTotalRaw)) ? Number(orderTotalRaw) : 0

    const shippingRaw = order.shippingAmount
    const shippingAmount = Number.isFinite(Number(shippingRaw)) ? Number(shippingRaw) : 0

    return centsToMoney(moneyToCents(orderTotal) + moneyToCents(shippingAmount))
}

export class DeliveryConfigurationError extends Error {
    statusCode: number
    statusMessage: string

    constructor(statusCode: number, statusMessage: string) {
        super(statusMessage)
        this.statusCode = statusCode
        this.statusMessage = statusMessage
    }
}

export class DeliveryService {
    private prisma: PrismaClient
    private staticProviders: Partial<Record<ShipmentProvider, DeliveryProvider>>

    constructor(client: PrismaClient = prisma) {
        this.prisma = client
        this.staticProviders = {
            SELF: new SelfDeliveryProvider(),
            LEOPARDS: new PakistanProvider('LEOPARDS'),
            TCS: new PakistanProvider('TCS'),
            MNP: new PakistanProvider('MNP'),
            TRAX: new PakistanProvider('TRAX'),
            POSTEX: new PakistanProvider('POSTEX')
        } as any
    }

    private supportedProviders(): ShipmentProvider[] {
        return DELIVERY_PROVIDER_CATALOG.map((p) => p.provider)
    }

    private async getOfferedProviders(tenantId: string): Promise<ShipmentProvider[]> {
        const settings = await this.prisma.storeSettings.upsert({
            where: { tenantId },
            create: { tenantId },
            update: {},
            select: { allowedDeliveryProviders: true }
        })

        const offered =
            settings?.allowedDeliveryProviders && settings.allowedDeliveryProviders.length > 0
                ? settings.allowedDeliveryProviders
                : this.supportedProviders()

        const supported = new Set(this.supportedProviders())
        return offered.filter((p): p is ShipmentProvider => supported.has(p as ShipmentProvider))
    }

    private parseProviderAccountConfig(provider: ShipmentProvider, accountConfig: unknown): ProviderApiConfig {
        const raw = isRecord(accountConfig) ? accountConfig : {}

        if (provider === 'MAYSTRO') {
            const token =
                typeof raw.apiToken === 'string'
                    ? raw.apiToken.trim()
                    : typeof raw.apiKey === 'string'
                        ? raw.apiKey.trim()
                        : undefined
            return {
                apiToken: token,
                storeId: typeof raw.storeId === 'string' ? raw.storeId.trim() : undefined,
                inventorySyncEnabled: raw.inventorySyncEnabled === true
            }
        }

        if (provider === 'YALIDINE') {
            return {
                apiId: typeof raw.apiId === 'string' ? raw.apiId.trim() : undefined,
                yalidineApiToken: typeof raw.apiToken === 'string' ? raw.apiToken.trim() : undefined,
                originWilayaId: typeof raw.originWilayaId === 'string' ? raw.originWilayaId.trim() : undefined,
                originWilayaName: typeof raw.originWilayaName === 'string' ? raw.originWilayaName.trim() : undefined
            }
        }

        // Pakistan providers - no credentials needed for MVP
        return {}
    }

    private async getProviderApiConfig(tenantId: string, provider: ShipmentProvider): Promise<ProviderApiConfig | null> {
        const account = await this.prisma.tenantDeliveryAccount.findUnique({
            where: { tenantId_provider: { tenantId, provider } },
            select: { isActive: true, config: true }
        })

        if (account) {
            if (!account.isActive) return null
            const cfg = this.parseProviderAccountConfig(provider, account.config)
            if (provider === 'MAYSTRO') return cfg.apiToken && cfg.storeId ? cfg : null
            if (provider === 'YALIDINE') return cfg.apiId && cfg.yalidineApiToken ? cfg : null
            return cfg
        }

        // Pakistan providers work without account config
        if (['LEOPARDS', 'TCS', 'MNP', 'TRAX', 'POSTEX'].includes(provider)) {
            return {}
        }

        return null
    }

    private async resolveProvider(
        tenantId: string,
        provider: ShipmentProvider
    ): Promise<{ impl: DeliveryProvider; apiConfig: ProviderApiConfig | null }> {
        const staticProvider = this.staticProviders[provider]
        if (staticProvider) return { impl: staticProvider, apiConfig: {} }

        if (provider === 'MAYSTRO') {
            const cfg = await this.getProviderApiConfig(tenantId, provider)
            return {
                impl: new MaystroProvider(cfg ? { apiToken: cfg.apiToken } : undefined),
                apiConfig: cfg
            }
        }

        if (provider === 'YALIDINE') {
            const cfg = await this.getProviderApiConfig(tenantId, provider)
            return {
                impl: new YalidineProvider({
                    apiId: cfg?.apiId,
                    apiToken: cfg?.yalidineApiToken,
                    originWilayaId: cfg?.originWilayaId,
                    originWilayaName: cfg?.originWilayaName
                }),
                apiConfig: cfg
            }
        }

        throw new Error(`Unsupported provider: ${provider}`)
    }

    async listCommuneNames(tenantId: string, wilayaCode: string): Promise<{ name: string }[]> {
        const offeredProviders = await this.getOfferedProviders(tenantId)

        const preferenceOrder: ShipmentProvider[] = ['MAYSTRO', 'YALIDINE']
        const orderedProviders = [
            ...preferenceOrder.filter((p) => offeredProviders.includes(p)),
            ...offeredProviders.filter((p) => !preferenceOrder.includes(p))
        ]

        const byNormalizedName = new Map<string, string>()

        for (const provider of orderedProviders) {
            try {
                const { impl } = await this.resolveProvider(tenantId, provider)
                if (!impl.listCommunes) continue
                const communes = await impl.listCommunes(wilayaCode)
                for (const commune of communes) {
                    const key = normalizeLocationName(commune.name)
                    if (!key || byNormalizedName.has(key)) continue
                    byNormalizedName.set(key, commune.name)
                }
            } catch {
                // A misconfigured/unreachable provider must not break the merged list for the others.
            }
        }

        return Array.from(byNormalizedName.values())
            .sort((a, b) => a.localeCompare(b))
            .map((name) => ({ name }))
    }

    private resolveServiceLevel(input: { serviceLevel?: string; deliveryMode?: 'home' | 'office' }) {
        if (typeof input.serviceLevel === 'string' && input.serviceLevel.trim().length > 0) {
            return input.serviceLevel.trim()
        }
        if (input.deliveryMode === 'home' || input.deliveryMode === 'office') return input.deliveryMode
        return undefined
    }

    private async findBestFallbackRate(input: {
        tenantId: string
        provider: ShipmentProvider
        destination: { wilayaCode: string; communeCode?: string }
        serviceLevel?: string
    }) {
        const communeCode = input.destination.communeCode?.trim() || null
        const serviceLevel = input.serviceLevel?.trim() || null

        const attempts: Array<{ communeCode: string | null; serviceLevel: string | null }> = []
        if (communeCode && serviceLevel) attempts.push({ communeCode, serviceLevel })
        if (communeCode) attempts.push({ communeCode, serviceLevel: null })
        if (serviceLevel) attempts.push({ communeCode: null, serviceLevel })
        attempts.push({ communeCode: null, serviceLevel: null })

        for (const attempt of attempts) {
            const rate = await this.prisma.deliveryRate.findFirst({
                where: {
                    tenantId: input.tenantId,
                    provider: input.provider,
                    wilayaCode: input.destination.wilayaCode,
                    communeCode: attempt.communeCode,
                    serviceLevel: attempt.serviceLevel,
                    isActive: true
                }
            })
            if (rate) return rate
        }

        return null
    }

    private async applyTenantOverridesToQuotes(input: {
        tenantId: string
        provider: ShipmentProvider
        destination: { wilayaCode: string; communeCode?: string }
        effectiveServiceLevel?: string
        quotes: QuoteOption[]
    }): Promise<QuoteOption[]> {
        const out: QuoteOption[] = []

        for (const quote of input.quotes) {
            const serviceLevel = quote.serviceLevel || input.effectiveServiceLevel
            const overrideRate = await this.findBestFallbackRate({
                tenantId: input.tenantId,
                provider: input.provider,
                destination: input.destination,
                serviceLevel
            })

            if (!overrideRate) {
                out.push(quote)
                continue
            }

            out.push({
                ...quote,
                providerPrice: quote.price,
                price: Number(overrideRate.price),
                currency: overrideRate.currency || quote.currency,
                estimatedMinDays: overrideRate.estimatedMinDays ?? quote.estimatedMinDays,
                estimatedMaxDays: overrideRate.estimatedMaxDays ?? quote.estimatedMaxDays,
                source: 'tenant-override'
            })
        }

        return out
    }

    async listOptions(input: QuoteRequest): Promise<QuoteOption[]> {
        const offeredProviders = await this.getOfferedProviders(input.tenantId)
        if (!offeredProviders.includes(input.provider)) return []

        const effectiveServiceLevel = this.resolveServiceLevel(input)

        const { impl, apiConfig } = await this.resolveProvider(input.tenantId, input.provider)
        const requiresCredentials = getProviderCatalogItem(input.provider).credentialFields.some((f) => f.required)

        const quoteInput: QuoteRequest = {
            ...input,
            serviceLevel: effectiveServiceLevel,
            originWilayaCode: input.originWilayaCode
        }

        // Same reasoning as rateShopOptions: fall through to the tenant's own saved
        // rate rather than failing the checkout when the carrier is unreachable.
        let providerQuotes: QuoteOption[] = []
        if (impl.quote && (!requiresCredentials || apiConfig)) {
            try {
                providerQuotes = await impl.quote(quoteInput)
            } catch (error) {
                console.error(`Quote failed for ${input.provider}`, error)
            }
        }

        if (providerQuotes.length > 0) {
            return this.applyTenantOverridesToQuotes({
                tenantId: input.tenantId,
                provider: input.provider,
                destination: input.destination,
                effectiveServiceLevel,
                quotes: providerQuotes
            })
        }

        const rate = await this.findBestFallbackRate({
            tenantId: input.tenantId,
            provider: input.provider,
            destination: input.destination,
            serviceLevel: effectiveServiceLevel
        })

        if (!rate) return []

        return [
            {
                provider: input.provider,
                serviceLevel: rate.serviceLevel || undefined,
                price: Number(rate.price),
                currency: rate.currency,
                estimatedMinDays: rate.estimatedMinDays || undefined,
                estimatedMaxDays: rate.estimatedMaxDays || undefined,
                source: 'fallback-rate'
            }
        ]
    }

    async rateShopOptions(input: Omit<QuoteRequest, 'provider'>): Promise<QuoteOption[]> {
        const offeredProviders = await this.getOfferedProviders(input.tenantId)
        const effectiveServiceLevel = this.resolveServiceLevel(input)

        const all: QuoteOption[] = []

        for (const provider of offeredProviders) {
            const { impl, apiConfig } = await this.resolveProvider(input.tenantId, provider)
            const requiresCredentials = getProviderCatalogItem(provider).credentialFields.some((f) => f.required)

            const quoteInput: QuoteRequest = {
                ...input,
                provider,
                serviceLevel: effectiveServiceLevel,
                originWilayaCode: input.originWilayaCode
            }

            // Rate-shopping is a shopper-facing path: one carrier being down, throttled
            // or misconfigured must never block the others or the checkout itself.
            let providerQuotes: QuoteOption[] = []
            if (impl.quote && (!requiresCredentials || apiConfig)) {
                try {
                    providerQuotes = await impl.quote(quoteInput)
                } catch (error) {
                    console.error(`Rate shop failed for ${provider}`, error)
                }
            }

            if (providerQuotes.length > 0) {
                all.push(
                    ...(await this.applyTenantOverridesToQuotes({
                        tenantId: input.tenantId,
                        provider,
                        destination: input.destination,
                        effectiveServiceLevel,
                        quotes: providerQuotes
                    }))
                )
                continue
            }

            const rate = await this.findBestFallbackRate({
                tenantId: input.tenantId,
                provider,
                destination: input.destination,
                serviceLevel: effectiveServiceLevel
            })

            if (!rate) continue

            all.push({
                provider,
                serviceLevel: rate.serviceLevel || undefined,
                price: Number(rate.price),
                currency: rate.currency,
                estimatedMinDays: rate.estimatedMinDays || undefined,
                estimatedMaxDays: rate.estimatedMaxDays || undefined,
                source: 'fallback-rate'
            })
        }

        all.sort((a, b) => a.price - b.price)
        return all
    }

    private static padWilaya(code: number) {
        return String(code).padStart(2, '0')
    }

    private static wilayaCodes(): string[] {
        return Array.from({ length: 58 }, (_, idx) => DeliveryService.padWilaya(idx + 1))
    }

    private static async mapWithConcurrency<T, R>(
        items: T[],
        concurrency: number,
        mapper: (item: T, index: number) => Promise<R>
    ): Promise<R[]> {
        const results: R[] = new Array(items.length)
        let nextIndex = 0

        const workers = Array.from({ length: Math.max(1, concurrency) }, async () => {
            while (nextIndex < items.length) {
                const current = nextIndex++
                if (current >= items.length) return
                results[current] = await mapper(items[current], current)
            }
        })

        await Promise.all(workers)
        return results
    }

    async getProviderLiveRatesByWilaya(input: {
        tenantId: string
        provider: ShipmentProvider
        deliveryMode?: 'home' | 'office'
        serviceLevel?: string
        weight?: number
        codAmount?: number
        originWilayaCode?: string
        communeCode?: string
        /** Skip the cache and re-quote the carrier. */
        forceRefresh?: boolean
    }): Promise<CarrierRateRow[]> {
        const catalogItem = getProviderCatalogItem(input.provider)
        if (!catalogItem.supports.quote) {
            throw new DeliveryConfigurationError(400, 'Provider does not support live rates')
        }

        const deliveryMode = input.deliveryMode ?? 'home'

        const effectiveServiceLevel = this.resolveServiceLevel({
            deliveryMode: input.deliveryMode,
            serviceLevel: input.serviceLevel
        })

        const { impl, apiConfig } = await this.resolveProvider(input.tenantId, input.provider)
        const requiresCredentials = catalogItem.credentialFields.some((f) => f.required)
        if (requiresCredentials && !apiConfig) {
            throw new DeliveryConfigurationError(400, 'Delivery provider credentials are not configured')
        }
        if (!impl.quote) {
            throw new DeliveryConfigurationError(400, 'Provider does not support live rates')
        }

        const wilayaCodes = DeliveryService.wilayaCodes()
        const communeCode =
            typeof input.communeCode === 'string' && input.communeCode.trim().length > 0 ? input.communeCode.trim() : undefined
        const weight = typeof input.weight === 'number' && Number.isFinite(input.weight) && input.weight > 0 ? input.weight : 1
        const codAmount =
            typeof input.codAmount === 'number' && Number.isFinite(input.codAmount) && input.codAmount > 0 ? input.codAmount : undefined

        // Rebuilding this table costs one request per destination wilaya. Carrier
        // prices move maybe monthly, so serve the last build unless the operator asks
        // for a fresh one — that is what keeps a page visit from spending 58 calls.
        if (!input.forceRefresh) {
            const cached = await this.readCarrierRateCache(input.tenantId, input.provider, deliveryMode)
            if (cached) return cached
        }

        // Carriers publish very different quotas — Yalidine throttles hard and answers
        // a burst with 403/429 — so the fan-out is paced per carrier rather than at a
        // single optimistic width.
        const concurrency = DeliveryService.liveRateConcurrency(input.provider)

        let systemicFailure: unknown = null
        let consecutiveFailures = 0
        const deadline = Date.now() + CARRIER_RATE_BUILD_BUDGET_MS

        const rows = await DeliveryService.mapWithConcurrency(wilayaCodes, concurrency, async (wilayaCode) => {
            const blank = { wilayaCode, carrierPrice: null, currency: 'DZD', serviceLevel: effectiveServiceLevel }
            if (systemicFailure) return blank

            // A blocked carrier does not always answer — it can simply stop responding,
            // and every request then burns its own timeout and retries. Without a budget
            // and a run of failures to stop on, one click hangs for many minutes.
            if (Date.now() > deadline) {
                systemicFailure = new DeliveryConfigurationError(504, 'Carrier took too long to price every wilaya')
                return blank
            }
            if (consecutiveFailures >= CARRIER_RATE_FAILURE_STREAK) {
                systemicFailure = new DeliveryConfigurationError(502, 'Carrier stopped answering rate requests')
                return blank
            }

            try {
                const quotes = await impl.quote!({
                    tenantId: input.tenantId,
                    provider: input.provider,
                    destination: { wilayaCode, communeCode },
                    weight,
                    codAmount,
                    deliveryMode: input.deliveryMode,
                    serviceLevel: effectiveServiceLevel,
                    originWilayaCode: input.originWilayaCode
                })

                consecutiveFailures = 0
                const best = quotes.length ? quotes.reduce((a, b) => (a.price <= b.price ? a : b)) : null
                return {
                    wilayaCode,
                    carrierPrice: best ? best.price : null,
                    currency: best?.currency || 'DZD',
                    serviceLevel: effectiveServiceLevel
                }
            } catch (error) {
                // Throttled or unauthorized dooms every remaining wilaya, so stop at
                // once. Anything else might be one bad destination, so allow a short
                // run before concluding the carrier is simply down.
                consecutiveFailures += 1
                if (isSystemicYalidineFailure(error) || error instanceof MaystroIntegrationError) {
                    systemicFailure = error
                }
                return blank
            }
        })

        if (systemicFailure) {
            const status = (systemicFailure as any)?.statusCode
            const message = (systemicFailure as any)?.statusMessage
            throw new DeliveryConfigurationError(
                status === 429 || status === 403 || status === 401 ? status : 502,
                message || 'Carrier refused the rate request'
            )
        }

        await this.writeCarrierRateCache(input.tenantId, input.provider, deliveryMode, effectiveServiceLevel, rows)

        return rows
    }

    private static liveRateConcurrency(provider: ShipmentProvider): number {
        return provider === 'YALIDINE' ? 2 : 8
    }

    private async readCarrierRateCache(
        tenantId: string,
        provider: ShipmentProvider,
        deliveryMode: string
    ): Promise<CarrierRateRow[] | null> {
        const entry = await this.prisma.deliveryCarrierRateCache.findUnique({
            where: { tenantId_provider_deliveryMode: { tenantId, provider, deliveryMode } }
        })
        if (!entry) return null

        const age = Date.now() - entry.fetchedAt.getTime()
        if (age > CARRIER_RATE_CACHE_TTL_MS) return null

        return Array.isArray(entry.rates) ? (entry.rates as unknown as CarrierRateRow[]) : null
    }

    private async writeCarrierRateCache(
        tenantId: string,
        provider: ShipmentProvider,
        deliveryMode: string,
        serviceLevel: string | undefined,
        rates: CarrierRateRow[]
    ): Promise<void> {
        // A build where the carrier answered nothing is not worth remembering — it
        // would pin an empty table for a day over what was probably a transient fault.
        if (!rates.some((row) => row.carrierPrice != null)) return

        const payload = { serviceLevel: serviceLevel ?? null, rates: rates as unknown as Prisma.InputJsonValue, fetchedAt: new Date() }

        await this.prisma.deliveryCarrierRateCache.upsert({
            where: { tenantId_provider_deliveryMode: { tenantId, provider, deliveryMode } },
            create: { tenantId, provider, deliveryMode, ...payload },
            update: payload
        })
    }

    /** When the table was last rebuilt from the carrier, so the admin can say so. */
    async getCarrierRateCacheInfo(tenantId: string, provider: ShipmentProvider) {
        const entries = await this.prisma.deliveryCarrierRateCache.findMany({
            where: { tenantId, provider },
            select: { deliveryMode: true, fetchedAt: true }
        })
        return Object.fromEntries(entries.map((e) => [e.deliveryMode, e.fetchedAt.toISOString()]))
    }

    /**
     * Resolve one provider for an admin-side lookup, failing loudly rather than
     * silently returning nothing — the admin needs to know *why* a carrier can't
     * answer, unlike the storefront where a dead provider is just skipped.
     */
    private async resolveProviderForAdmin(tenantId: string, provider: ShipmentProvider) {
        const catalogItem = getProviderCatalogItem(provider)
        const { impl, apiConfig } = await this.resolveProvider(tenantId, provider)

        const requiresCredentials = catalogItem.credentialFields.some((f) => f.required)
        if (requiresCredentials && !apiConfig) {
            throw new DeliveryConfigurationError(400, 'Delivery provider credentials are not configured')
        }

        return { impl, catalogItem }
    }

    /**
     * The carrier's own commune list for a wilaya, ids included. Generic across
     * carriers: anything implementing `listCommunes` answers here.
     */
    async listProviderCommunes(input: {
        tenantId: string
        provider: ShipmentProvider
        wilayaCode: string
    }): Promise<ProviderCommune[]> {
        const { impl } = await this.resolveProviderForAdmin(input.tenantId, input.provider)
        if (!impl.listCommunes) {
            throw new DeliveryConfigurationError(400, 'Provider does not expose communes')
        }
        return impl.listCommunes(input.wilayaCode)
    }

    /**
     * Places the customer can collect from, normalized across carriers — Maystro
     * pickup points and stop desks, Yalidine agencies.
     */
    async listProviderPickupPoints(input: {
        tenantId: string
        provider: ShipmentProvider
        wilayaCode: string
        communeCode?: string
        /**
         * Set on the unauthenticated storefront route: an anonymous caller must not be
         * able to spend the tenant's carrier API quota on a carrier they don't even sell.
         */
        requireOffered?: boolean
    }): Promise<ProviderPickupPoint[]> {
        if (input.requireOffered) {
            const offered = await this.getOfferedProviders(input.tenantId)
            if (!offered.includes(input.provider)) {
                throw new DeliveryConfigurationError(400, 'Provider is not offered by this store')
            }
        }

        const { impl } = await this.resolveProviderForAdmin(input.tenantId, input.provider)
        if (!impl.listPickupPoints) {
            throw new DeliveryConfigurationError(400, 'Provider does not offer pickup points')
        }
        return impl.listPickupPoints({ wilayaCode: input.wilayaCode, communeCode: input.communeCode })
    }

    /**
     * The carrier's raw price for one exact commune, per delivery mode.
     *
     * Deliberately calls `impl.quote()` rather than `listOptions()`: the admin is
     * asking what the carrier charges, not what the shopper would pay, so tenant
     * overrides and fallback rates must not be applied.
     */
    async getProviderCommunePrice(input: {
        tenantId: string
        provider: ShipmentProvider
        wilayaCode: string
        communeCode: string
        weight?: number
        codAmount?: number
        originWilayaCode?: string
    }): Promise<Record<'home' | 'office', { price: number | null; currency: string }>> {
        const { impl, catalogItem } = await this.resolveProviderForAdmin(input.tenantId, input.provider)
        if (!catalogItem.supports.quote || !impl.quote) {
            throw new DeliveryConfigurationError(400, 'Provider does not support live rates')
        }

        const weight = typeof input.weight === 'number' && Number.isFinite(input.weight) && input.weight > 0 ? input.weight : 1
        const codAmount =
            typeof input.codAmount === 'number' && Number.isFinite(input.codAmount) && input.codAmount > 0
                ? input.codAmount
                : undefined

        const modes = ['home', 'office'] as const
        const results = await Promise.all(
            modes.map(async (deliveryMode) => {
                const quotes = await impl.quote!({
                    tenantId: input.tenantId,
                    provider: input.provider,
                    destination: { wilayaCode: input.wilayaCode, communeCode: input.communeCode },
                    weight,
                    codAmount,
                    deliveryMode,
                    serviceLevel: this.resolveServiceLevel({ deliveryMode }),
                    originWilayaCode: input.originWilayaCode
                })

                const best = quotes.length ? quotes.reduce((a, b) => (a.price <= b.price ? a : b)) : null
                return [deliveryMode, { price: best ? best.price : null, currency: best?.currency || 'DZD' }] as const
            })
        )

        return Object.fromEntries(results) as Record<'home' | 'office', { price: number | null; currency: string }>
    }

    async listCompanies(tenantId: string) {
        const offered = await this.getOfferedProviders(tenantId)
        return offered.map((provider) => ({
            code: provider,
            name: getProviderCatalogItem(provider).name,
            provider
        }))
    }

    async listShipments(
        tenantId: string,
        filters: { status?: ShipmentStatus; provider?: ShipmentProvider; search?: string }
    ) {
        return this.prisma.shipment.findMany({
            where: {
                tenantId,
                status: filters.status,
                provider: filters.provider,
                OR: filters.search
                    ? [
                        { orderId: { contains: filters.search, mode: 'insensitive' } },
                        { contactName: { contains: filters.search, mode: 'insensitive' } },
                        { contactPhone: { contains: filters.search, mode: 'insensitive' } },
                        { providerShipmentId: { contains: filters.search, mode: 'insensitive' } }
                    ]
                    : undefined
            },
            include: {
                order: {
                    select: {
                        id: true,
                        totalAmount: true,
                        currency: true
                    }
                }
            },
            orderBy: { createdAt: 'desc' }
        })
    }

    async createShipment(input: CreateShipmentInput) {
        // Idempotency: return existing shipment if same provider+order+tenant
        const existing = await this.prisma.shipment.findUnique({
            where: {
                tenantId_provider_orderId: {
                    tenantId: input.tenantId,
                    provider: input.provider,
                    orderId: input.orderId
                }
            },
            include: { events: true }
        })
        if (existing) return existing

        // Ensure order belongs to tenant
        const order = await this.prisma.order.findFirst({
            where: { id: input.orderId, tenantId: input.tenantId },
            include: {
                tenant: true,
                items: {
                    include: {
                        product: { select: { title: true } },
                        variant: { select: { sku: true } }
                    }
                }
            }
        })
        if (!order) throw new Error('Order not found for tenant')

        const inferredDeliveryMode = input.deliveryMode ?? normalizeOrderDeliveryMode((order as any).deliveryMode)
        const explicitCodAmount =
            Number.isFinite(Number((input as any).codAmount)) && Number((input as any).codAmount) >= 0
                ? Number((input as any).codAmount)
                : null
        const total = computeOrderTotalWithShipping(order as any)
        const paidAmount = Number.isFinite(Number((order as any).paidAmount)) ? Number((order as any).paidAmount) : 0
        const codAmount = explicitCodAmount ?? Math.max(0, total - paidAmount)
        const baseInput: CreateShipmentInput = { ...input, deliveryMode: inferredDeliveryMode, codAmount }

        const orderPickupPoint =
            typeof (order as any).shippingPickupPoint === 'number' && Number.isFinite((order as any).shippingPickupPoint)
                ? Math.trunc((order as any).shippingPickupPoint)
                : null

        const offeredProviders = await this.getOfferedProviders(input.tenantId)
        if (!offeredProviders.includes(baseInput.provider)) {
            throw new DeliveryConfigurationError(403, 'Delivery provider is not enabled for this store')
        }

        const effectiveServiceLevel = this.resolveServiceLevel(baseInput)
        const { impl, apiConfig } = await this.resolveProvider(baseInput.tenantId, baseInput.provider)
        const requiresCredentials = getProviderCatalogItem(baseInput.provider).credentialFields.some((f) => f.required)
        if (requiresCredentials && !apiConfig) {
            throw new DeliveryConfigurationError(400, 'Delivery provider credentials are not configured')
        }

        // The chosen pickup point belongs to every carrier that has one, not just
        // Maystro. Leaving it out of Yalidine's metadata meant a confirmed agency order
        // reached the carrier with no stopdesk_id and was refused.
        const metadataWithPickupPoint =
            orderPickupPoint && baseInput.metadata?.pickupPoint == null
                ? { ...(baseInput.metadata || {}), pickupPoint: orderPickupPoint }
                : baseInput.metadata

        const maybeAugmentedMetadata =
            baseInput.provider === 'MAYSTRO'
                ? orderPickupPoint
                    ? { ...(metadataWithPickupPoint || {}), maystroDeliveryType: 3 }
                    : metadataWithPickupPoint
                : baseInput.provider === 'YALIDINE'
                    ? {
                        ...(metadataWithPickupPoint || {}),
                        items:
                            Array.isArray(baseInput.metadata?.items) && baseInput.metadata.items.length
                                ? baseInput.metadata.items
                                : (order as any).items.map((item: any) => ({
                                    title: item.product?.title || item.variant?.sku || 'Item',
                                    quantity: item.quantity
                                }))
                    }
                    : metadataWithPickupPoint

        const result =
            baseInput.provider === 'MAYSTRO'
                ? await this.createMaystroShipment({
                    ...baseInput,
                    serviceLevel: effectiveServiceLevel,
                    apiToken: apiConfig!.apiToken!,
                    storeId: apiConfig!.storeId!,
                    metadata: maybeAugmentedMetadata
                })
                : await impl.createShipment({ ...baseInput, serviceLevel: effectiveServiceLevel, metadata: maybeAugmentedMetadata })

        const mergedMetadata =
            baseInput.provider === 'MAYSTRO'
                ? {
                    ...(maybeAugmentedMetadata || {}),
                    maystro: result.raw ?? null
                }
                : maybeAugmentedMetadata ?? result.raw ?? undefined

        const shipment = await this.prisma.shipment.create({
            data: {
                tenant: { connect: { id: baseInput.tenantId } },
                order: { connect: { tenantId_id: { tenantId: baseInput.tenantId, id: baseInput.orderId } } },
                provider: baseInput.provider,
                providerShipmentId: result.providerShipmentId,
                status: result.status || ShipmentStatus.PENDING,
                serviceLevel: effectiveServiceLevel,
                price: result.price ?? baseInput.price ?? undefined,
                currency: result.currency || baseInput.currency || 'DZD',
                contactName: baseInput.contactName,
                contactPhone: baseInput.contactPhone,
                wilayaCode: baseInput.wilayaCode,
                communeCode: baseInput.communeCode,
                addressLine1: baseInput.addressLine1,
                addressLine2: baseInput.addressLine2,
                notes: baseInput.notes,
                labelUrl: result.labelUrl ?? undefined,
                trackingUrl: result.trackingUrl ?? undefined,
                metadata: mergedMetadata as any
            }
        })

        if (result.status) {
            await this.prisma.shipmentEvent.create({
                data: {
                    tenantId: baseInput.tenantId,
                    shipmentId: shipment.id,
                    status: result.status,
                    description: 'Shipment created',
                    rawPayload: result.raw || null
                }
            })
        }

        // Mirror the chosen carrier and shipping price on the order for admin UIs / invoices.
        const shippingAmount = shipment.price != null ? Number(shipment.price) : null
        const totalWithShippingAmount =
            shippingAmount == null
                ? (order as any).totalWithShippingAmount ?? null
                : centsToMoney(moneyToCents(Number((order as any).totalAmount || 0)) + moneyToCents(shippingAmount))

        await this.prisma.order.updateMany({
            where: { tenantId: baseInput.tenantId, id: baseInput.orderId },
            data: {
                shippingProvider: baseInput.provider,
                shippingServiceLevel: effectiveServiceLevel ?? undefined,
                shippingAmount: shippingAmount ?? undefined,
                shippingCurrency: shipment.currency || undefined,
                shippingWilayaCode: baseInput.wilayaCode || undefined,
                shippingCommuneCode: baseInput.communeCode || undefined,
                shippingAddressLine1: baseInput.addressLine1 || undefined,
                shippingAddressLine2: baseInput.addressLine2 || undefined,
                shippingNotes: baseInput.notes || undefined,
                deliveryMode: inferredDeliveryMode === 'office' ? 'pickup' : inferredDeliveryMode ?? (order as any).deliveryMode,
                totalWithShippingAmount: totalWithShippingAmount ?? undefined,
                shippingPickupPoint:
                    typeof (maybeAugmentedMetadata as any)?.pickupPoint === 'number'
                        ? Math.trunc((maybeAugmentedMetadata as any).pickupPoint)
                        : undefined
            } as any
        })

        return shipment
    }

    private async createMaystroShipment(
        input: CreateShipmentInput & {
            apiToken: string
            storeId: string
        }
    ) {
        if (!input.communeCode || !input.wilayaCode) {
            throw new DeliveryConfigurationError(400, 'wilayaCode and communeCode are required for Maystro shipments')
        }

        const rawDeliveryType =
            input.metadata?.maystroDeliveryType ??
            input.metadata?.deliveryType ??
            input.metadata?.maystro?.deliveryType ??
            undefined
        const parsedDeliveryType = typeof rawDeliveryType === 'number' ? rawDeliveryType : Number(rawDeliveryType)
        const deliveryType: 1 | 2 | 3 =
            parsedDeliveryType === 1 || parsedDeliveryType === 2 || parsedDeliveryType === 3
                ? (parsedDeliveryType as 1 | 2 | 3)
                : input.deliveryMode === 'home'
                    ? 1
                    : 2

        const rawPickupPoint =
            input.metadata?.pickupPoint ??
            input.metadata?.maystroPickupPoint ??
            input.metadata?.maystro?.pickupPoint ??
            undefined
        const pickupPoint = rawPickupPoint == null ? undefined : Number(rawPickupPoint)

        const orderService = new MaystroOrderService(this.prisma)
        const destinationText = await this.buildMaystroDestinationText({
            apiToken: input.apiToken,
            wilayaCode: input.wilayaCode,
            communeCode: input.communeCode,
            addressLine1: input.addressLine1,
            addressLine2: input.addressLine2
        })

        const mapping = await orderService.createOrderFromLocalOrder({
            tenantId: input.tenantId,
            apiToken: input.apiToken,
            storeId: input.storeId,
            localOrderId: input.orderId,
            customerName: input.contactName,
            customerPhone: input.contactPhone,
            customerPhone2: typeof input.metadata?.customerPhone2 === 'string' ? input.metadata.customerPhone2 : undefined,
            destinationText,
            noteToDriver: input.notes,
            express: input.metadata?.express === true,
            wilaya: input.wilayaCode,
            commune: input.communeCode,
            deliveryType,
            pickupPoint: Number.isFinite(pickupPoint as any) ? (pickupPoint as number) : undefined
        })

        return {
            // Use tracking (= display_id) as providerShipmentId — required by the bordereau endpoint.
            // The UUID (maystroOrderId) is preserved in raw for reference.
            providerShipmentId: mapping.tracking ?? mapping.maystroOrderId ?? undefined,
            status: mapping.success ? ShipmentStatus.REQUESTED : ShipmentStatus.PENDING,
            price: mapping.deliveryPrice != null ? Number(mapping.deliveryPrice) : undefined,
            currency: 'DZD',
            labelUrl: undefined as string | undefined,
            trackingUrl: undefined as string | undefined,
            raw: {
                maystroOrderId: mapping.maystroOrderId,
                tracking: mapping.tracking,
                success: mapping.success
            }
        }
    }

    private async buildMaystroDestinationText(input: {
        apiToken: string
        wilayaCode: string
        communeCode: string
        addressLine1?: string
        addressLine2?: string
    }): Promise<string> {
        const fromAddress = [input.addressLine1, input.addressLine2]
            .map((value) => (typeof value === 'string' ? value.trim() : ''))
            .filter(Boolean)
            .join(', ')

        const fallbackFromCodes = [input.communeCode, input.wilayaCode]
            .map((value) => (typeof value === 'string' ? value.trim() : ''))
            .filter(Boolean)
            .join(', ')

        let locationPart = fallbackFromCodes
        try {
            const location = new MaystroLocationService(this.prisma)
            const resolved = await location.resolveWilayaAndCommune({
                apiToken: input.apiToken,
                wilaya: input.wilayaCode,
                commune: input.communeCode
            })

            const fromNames = [resolved.communeName, resolved.wilayaName].filter(Boolean).join(', ')
            if (fromNames) locationPart = fromNames
        } catch {
            // Do not block shipment creation if location-name lookup fails.
        }

        if (fromAddress && locationPart) return `${fromAddress}, ${locationPart}`
        if (fromAddress) return fromAddress
        return locationPart
    }

    async getShipment(tenantId: string, shipmentId: string) {
        return this.prisma.shipment.findFirst({
            where: { id: shipmentId, tenantId },
            include: { events: true, order: true }
        })
    }

    async trackShipment(tenantId: string, shipmentId: string) {
        const shipment = await this.getShipment(tenantId, shipmentId)
        if (!shipment) return null
        const { impl, apiConfig } = await this.resolveProvider(tenantId, shipment.provider)
        const requiresCredentials = getProviderCatalogItem(shipment.provider).credentialFields.some((f) => f.required)

        let providerEvents: TrackingEvent[] = []
        if (impl.track && (!requiresCredentials || apiConfig)) {
            providerEvents = await impl.track(shipment as Shipment)
        }

        // Persist new events if any
        const newEvents = providerEvents.map((e) => ({
            tenantId,
            shipmentId: shipment.id,
            status: e.status || undefined,
            code: e.code,
            description: e.description,
            rawPayload: e.raw || undefined,
            eventTime: e.eventTime || new Date()
        }))
        if (newEvents.length) {
            await this.prisma.shipmentEvent.createMany({ data: newEvents, skipDuplicates: true })
        }

        const events = await this.prisma.shipmentEvent.findMany({
            where: { shipmentId: shipment.id, tenantId },
            orderBy: { eventTime: 'desc' }
        })

        return { shipment, events }
    }

    async handleMaystroWebhook(tenantId: string, rawPayload: any) {
        const account = await this.prisma.tenantDeliveryAccount.findUnique({
            where: { tenantId_provider: { tenantId, provider: 'MAYSTRO' } },
            select: { config: true }
        })
        const raw = typeof account?.config === 'object' && account?.config !== null ? (account.config as any) : {}
        const inventorySyncEnabled = raw?.inventorySyncEnabled === true

        const webhook = new MaystroWebhookService(this.prisma)
        return webhook.handleWebhook({ tenantId, raw: rawPayload, inventorySyncEnabled })
    }

    async updateSelfStatus(tenantId: string, shipmentId: string, status: ShipmentStatus, actor?: { userId?: string | null }) {
        const shipment = await this.prisma.shipment.findFirst({
            where: { id: shipmentId, tenantId, provider: 'SELF' }
        })
        if (!shipment) throw new Error('Shipment not found')
        const updated = await this.prisma.shipment.update({
            where: { tenantId_id: { tenantId, id: shipment.id } },
            data: { status }
        })
        await this.prisma.shipmentEvent.create({
            data: {
                tenantId,
                shipmentId,
                status,
                description: 'Self delivery status update'
            }
        })

        const orderStatus =
            status === 'DELIVERED'
                ? 'DELIVERED'
                : status === 'IN_TRANSIT'
                    ? 'SHIPPED'
                    : status === 'CANCELLED'
                        ? 'CANCELLED'
                        : status === 'RETURNED'
                            ? 'RETURNED'
                            : null
        if (orderStatus) {
            const orders = new OrdersService()
            await orders.applyCarrierStatus(tenantId, shipment.orderId, orderStatus, actor)
        }

        return updated
    }


    async getDeliveryRates(tenantId: string, provider: ShipmentProvider) {
        return this.prisma.deliveryRate.findMany({
            where: { tenantId, provider },
            orderBy: [{ wilayaCode: 'asc' }, { communeCode: 'asc' }, { serviceLevel: 'asc' }]
        })
    }

    async updateDeliveryRates(
        tenantId: string,
        provider: ShipmentProvider,
        rates: {
            wilayaCode: string
            price: number
            communeCode?: string | null
            serviceLevel?: string | null
            currency?: string
            isActive?: boolean
            estimatedMinDays?: number | null
            estimatedMaxDays?: number | null
        }[]
    ) {
        return this.prisma.$transaction(
            rates.map((rate) => {
                const communeCode =
                    typeof rate.communeCode === 'string' && rate.communeCode.trim().length > 0
                        ? rate.communeCode.trim()
                        : null
                const serviceLevel =
                    typeof rate.serviceLevel === 'string' && rate.serviceLevel.trim().length > 0
                        ? rate.serviceLevel.trim()
                        : null
                const currency = typeof rate.currency === 'string' && rate.currency.trim().length > 0 ? rate.currency.trim() : 'DZD'
                const isActive = rate.isActive ?? true

                return this.prisma.deliveryRate.upsert({
                    where: {
                        tenantId_provider_wilayaCode_communeCode_serviceLevel: {
                            tenantId,
                            provider,
                            wilayaCode: rate.wilayaCode,
                            communeCode,
                            serviceLevel
                        }
                    },
                    create: {
                        tenantId,
                        provider,
                        wilayaCode: rate.wilayaCode,
                        communeCode,
                        serviceLevel,
                        price: rate.price,
                        currency,
                        isActive,
                        estimatedMinDays: rate.estimatedMinDays ?? undefined,
                        estimatedMaxDays: rate.estimatedMaxDays ?? undefined
                    },
                    update: {
                        price: rate.price,
                        currency,
                        isActive,
                        estimatedMinDays: rate.estimatedMinDays ?? undefined,
                        estimatedMaxDays: rate.estimatedMaxDays ?? undefined
                    }
                })
            })
        )
    }
}
