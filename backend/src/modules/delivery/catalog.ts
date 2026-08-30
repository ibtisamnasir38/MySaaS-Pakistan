import type { ShipmentProvider } from '@prisma/client'

export type ProviderCredentialField = {
    key: string
    label: string
    required: boolean
    secret: boolean
}

export type DeliveryProviderCatalogItem = {
    provider: ShipmentProvider
    name: string
    supports: {
        quote: boolean
        createShipment: boolean
        track: boolean
        webhooks: boolean
    }
    credentialFields: ProviderCredentialField[]
}

export const DELIVERY_PROVIDER_CATALOG: DeliveryProviderCatalogItem[] = [
    {
        provider: 'MAYSTRO',
        name: 'Maystro',
        supports: { quote: true, createShipment: true, track: false, webhooks: true },
        credentialFields: [
            { key: 'apiToken', label: 'API Token', required: true, secret: true },
            { key: 'storeId', label: 'Store ID', required: true, secret: false },
            { key: 'inventorySyncEnabled', label: 'Inventory Sync Enabled', required: false, secret: false }
        ]
    },
    {
        provider: 'YALIDINE',
        name: 'Yalidine',
        supports: { quote: true, createShipment: true, track: true, webhooks: false },
        credentialFields: [
            { key: 'apiId', label: 'API ID', required: true, secret: true },
            { key: 'apiToken', label: 'API Token', required: true, secret: true },
            { key: 'originWilayaId', label: 'Origin Wilaya ID', required: false, secret: false },
            { key: 'originWilayaName', label: 'Origin Wilaya Name', required: false, secret: false },
            { key: 'webhookSecret', label: 'Webhook Secret', required: false, secret: true }
        ]
    },
    {
        provider: 'SELF',
        name: 'Self delivery',
        supports: { quote: false, createShipment: true, track: false, webhooks: false },
            credentialFields: []
  },
  {
    provider: 'LEOPARDS' as any,
    name: 'Leopards Courier (Pakistan)',
    supports: { quote: true, createShipment: true, track: true, webhooks: false },
    credentialFields: []
  },
  {
    provider: 'TCS' as any,
    name: 'TCS Courier (Pakistan)',
    supports: { quote: true, createShipment: true, track: true, webhooks: false },
    credentialFields: []
  },
  {
    provider: 'MNP' as any,
    name: 'M&P (Pakistan)',
    supports: { quote: true, createShipment: true, track: true, webhooks: false },
    credentialFields: []
  },
  {
    provider: 'TRAX' as any,
    name: 'Trax Courier (Pakistan)',
    supports: { quote: true, createShipment: true, track: true, webhooks: false },
    credentialFields: []
  },
  {
    provider: 'POSTEX' as any,
    name: 'PostEx (Pakistan)',
    supports: { quote: true, createShipment: true, track: true, webhooks: false },
    credentialFields: []
  }
]

export const getProviderCatalogItem = (provider: ShipmentProvider): DeliveryProviderCatalogItem => {
    const item = DELIVERY_PROVIDER_CATALOG.find((p) => p.provider === provider)
    if (!item) throw new Error(`Unsupported provider: ${provider}`)
    return item
}
