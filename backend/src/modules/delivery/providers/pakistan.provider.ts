import type { DeliveryProvider, QuoteRequest, QuoteOption, CreateShipmentInput, CreateShipmentResult, TrackingEvent } from './types'
import { ShipmentStatus } from '@prisma/client'

type PakistanProviderName = 'LEOPARDS' | 'TCS' | 'MNP' | 'TRAX' | 'POSTEX'

const PAKISTAN_RATES: Record<PakistanProviderName, { base: number, perKg: number, name: string }> = {
  LEOPARDS: { base: 250, perKg: 50, name: 'Leopards Courier' },
  TCS: { base: 300, perKg: 60, name: 'TCS Express' },
  MNP: { base: 200, perKg: 40, name: 'M&P Courier' },
  TRAX: { base: 220, perKg: 45, name: 'Trax Courier' },
  POSTEX: { base: 180, perKg: 35, name: 'PostEx' }
}

export class PakistanProvider implements DeliveryProvider {
  private providerName: PakistanProviderName

  constructor(providerName: string | PakistanProviderName = 'LEOPARDS') {
    const upper = providerName.toUpperCase() as PakistanProviderName
    this.providerName = (PAKISTAN_RATES[upper] ? upper : 'LEOPARDS') as PakistanProviderName
  }

  async quote(req: QuoteRequest): Promise<QuoteOption[]> {
    const rate = PAKISTAN_RATES[this.providerName]
    const weight = req.weight || 1
    const price = rate.base + (weight - 1) * rate.perKg

    // City-based pricing for Pakistan
    const destCode = req.destination.wilayaCode || req.destination.communeCode || ''
    const isMajorCity = ['KHI', 'LHE', 'ISB', 'RWP', 'FSD', 'MUL', 'KARACHI', 'LAHORE', 'ISLAMABAD'].some(c => 
      destCode.toUpperCase().includes(c) || (req.destination as any).city?.toUpperCase().includes(c)
    )
    
    const finalPrice = isMajorCity ? price : price + 100

    return [{
      provider: this.providerName as any,
      serviceLevel: 'standard',
      price: finalPrice,
      currency: 'PKR',
      estimatedMinDays: 1,
      estimatedMaxDays: isMajorCity ? 2 : 4,
      source: 'live-rate',
      providerPrice: finalPrice
    }]
  }

  async createShipment(input: CreateShipmentInput): Promise<CreateShipmentResult> {
    // MVP: Create local shipment, no external API call yet
    // Later you can integrate Leopards/TCS APIs here
    const trackingId = `${this.providerName}-${Date.now()}-${Math.random().toString(36).substr(2, 6).toUpperCase()}`
    
    return {
      providerShipmentId: trackingId,
      status: ShipmentStatus.PENDING,
      price: input.price,
      currency: 'PKR',
      trackingUrl: `https://track.${this.providerName.toLowerCase()}.com.pk/${trackingId}`,
      raw: {
        provider: this.providerName,
        trackingId,
        createdAt: new Date().toISOString(),
        codAmount: (input as any).codAmount,
        destination: input.wilayaCode || input.communeCode
      }
    }
  }

  async track(shipment: any): Promise<TrackingEvent[]> {
    return [{
      code: 'IN_TRANSIT',
      description: `Shipment in transit via ${PAKISTAN_RATES[this.providerName].name}`,
      status: ShipmentStatus.IN_TRANSIT,
      eventTime: new Date(),
      raw: shipment.metadata
    }]
  }
}
