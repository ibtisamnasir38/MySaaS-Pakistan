<script setup lang="ts">
import { computed } from 'vue'
import { PRICING_PLANS, pricingPlanCardForUi } from '~/shared/pricing/plans'

const { t, locale, tm, rt } = useI18n({ useScope: 'global' })
const isRtl = computed(() => locale.value === 'ar')

useSeoMeta({
  title: computed(() => t('saasLanding.seo.title')),
  description: computed(() => t('saasLanding.seo.description'))
})

const heroProof = computed(() => [
  { icon: 'lucide:store', value: '1,200+', label: t('saasLanding.stats.activeMerchants') },
  { icon: 'lucide:wallet', value: '50M+ DA', label: t('saasLanding.stats.revenueGenerated') },
  { icon: 'lucide:shield-check', value: '99.9%', label: t('saasLanding.stats.uptime') }
])

const integrationLogos = [
  { name: 'Maystro', icon: 'lucide:truck' },
  { name: 'Yalidine', icon: 'lucide:package' },
  { name: 'Stripe', icon: 'lucide:credit-card' },
  { name: 'WhatsApp', icon: 'lucide:message-circle' },
  { name: 'Telegram', icon: 'lucide:send' },
  { name: 'Meta Ads', icon: 'lucide:megaphone' },
  { name: 'Google Pixel', icon: 'lucide:bar-chart-2' },
  { name: 'AWS S3', icon: 'lucide:cloud' }
]

const stepCards = computed(() => [
  {
    step: '01',
    icon: 'lucide:pen-tool',
    title: t('saasLanding.storyteller.steps.design.title'),
    description: t('saasLanding.storyteller.steps.design.description'),
    bullets: [
      { icon: 'lucide:layout-template', label: t('saasLanding.features.items.templates.title') },
      { icon: 'lucide:globe', label: t('marketing.featuresPage.items.domains.title') }
    ]
  },
  {
    step: '02',
    icon: 'lucide:shopping-cart',
    title: t('saasLanding.storyteller.steps.sell.title'),
    description: t('saasLanding.storyteller.steps.sell.description'),
    bullets: [
      { icon: 'lucide:credit-card', label: t('marketing.featuresPage.items.payments.title') },
      { icon: 'lucide:package', label: t('auth.login.hero.carousel.orders.title') }
    ]
  },
  {
    step: '03',
    icon: 'lucide:truck',
    title: t('saasLanding.storyteller.steps.ship.title'),
    description: t('saasLanding.storyteller.steps.ship.description'),
    bullets: [
      { icon: 'lucide:truck', label: t('marketing.featuresPage.items.logistics.title') },
      { icon: 'lucide:badge-dollar-sign', label: t('saasLanding.trust.secure') }
    ]
  },
  {
    step: '04',
    icon: 'lucide:bar-chart-3',
    title: t('saasLanding.storyteller.steps.grow.title'),
    description: t('saasLanding.storyteller.steps.grow.description'),
    bullets: [
      { icon: 'lucide:line-chart', label: t('marketing.featuresPage.items.analytics.title') },
      { icon: 'lucide:sparkles', label: t('saasLanding.features.items.aiTools.title') }
    ]
  }
])

const metrics = computed(() => [
  { value: '1,200+', label: t('saasLanding.stats.activeMerchants'), detail: t('saasLanding.hero.chips.storefront') },
  { value: '50M+', label: t('saasLanding.stats.revenueGenerated'), detail: t('saasLanding.stats.gmvDetail') },
  { value: '99.9%', label: t('saasLanding.stats.uptime'), detail: t('saasLanding.trust.cloud') }
])

const themeShowcase = computed(() => {
  const ids = ['minimal', 'modern', 'cyber', 'food', 'classic', 'cozy'] as const
  const fonts: Record<string, string> = {
    minimal: 'ui-sans-serif, system-ui, sans-serif',
    modern: 'ui-sans-serif, system-ui, sans-serif',
    cyber: 'ui-monospace, SFMono-Regular, monospace',
    food: '"Playfair Display", Georgia, serif',
    classic: 'Georgia, "Times New Roman", serif',
    cozy: '"Playfair Display", Georgia, serif'
  }
  const slugs: Record<string, string> = {
    minimal: 'minimal',
    modern: 'modern',
    cyber: 'cyber',
    food: 'fresh',
    classic: 'classic',
    cozy: 'cozy'
  }
  return ids.map(id => ({
    id,
    name: t(`saasLanding.cinematic.templates.items.${id}.name`),
    category: t(`saasLanding.cinematic.templates.items.${id}.category`),
    tagline: t(`saasLanding.cinematic.templates.items.${id}.tagline`),
    brand: t(`saasLanding.cinematic.templates.items.${id}.name`).toUpperCase(),
    brandFont: fonts[id],
    urlSlug: slugs[id],
    to: `/themes#${id}`
  }))
})

const merchantWall = computed(() => {
  const ids = ['atlas', 'djezzy', 'kasbah', 'souk', 'henna', 'argan', 'noor', 'tamanrasset', 'berber', 'saharaTech', 'dattes', 'rose']
  const palettes: Record<string, { gradient: string; font: string }> = {
    atlas: { gradient: 'linear-gradient(135deg, #1e3a8a, #3b82f6)', font: 'Georgia, serif' },
    djezzy: { gradient: 'linear-gradient(135deg, #831843, #be185d)', font: '"Playfair Display", serif' },
    kasbah: { gradient: 'linear-gradient(135deg, #78350f, #d97706)', font: 'ui-serif, Georgia, serif' },
    souk: { gradient: 'linear-gradient(135deg, #064e3b, #10b981)', font: 'ui-monospace, monospace' },
    henna: { gradient: 'linear-gradient(135deg, #581c87, #c084fc)', font: 'Georgia, serif' },
    argan: { gradient: 'linear-gradient(135deg, #422006, #ca8a04)', font: 'ui-serif, Georgia, serif' },
    noor: { gradient: 'linear-gradient(135deg, #0c0a09, #44403c)', font: 'ui-sans-serif, system-ui' },
    tamanrasset: { gradient: 'linear-gradient(135deg, #7c2d12, #ea580c)', font: 'Georgia, serif' },
    berber: { gradient: 'linear-gradient(135deg, #14532d, #65a30d)', font: 'ui-sans-serif, system-ui' },
    saharaTech: { gradient: 'linear-gradient(135deg, #0f172a, #6366f1)', font: 'ui-monospace, monospace' },
    dattes: { gradient: 'linear-gradient(135deg, #713f12, #fbbf24)', font: '"Playfair Display", serif' },
    rose: { gradient: 'linear-gradient(135deg, #9d174d, #f9a8d4)', font: 'Georgia, serif' }
  }
  return ids.map(id => {
    const name = t(`saasLanding.cinematic.merchants.items.${id}.name`)
    return {
      name,
      category: t(`saasLanding.cinematic.merchants.items.${id}.category`),
      mark: name.split(' ').map(w => w[0]).slice(0, 2).join(''),
      gradient: palettes[id].gradient,
      font: palettes[id].font
    }
  })
})

const merchantMetrics = computed(() => [
  { value: '1,200+', label: t('saasLanding.cinematic.merchants.metrics.stores') },
  { value: '480K+', label: t('saasLanding.cinematic.merchants.metrics.orders') },
  { value: '48 / 58', label: t('saasLanding.cinematic.merchants.metrics.wilayas') }
])

const trialSteps = computed(() => {
  const ids = ['signup', 'customize', 'launch', 'scale'] as const
  return ids.map(id => ({
    day: t(`saasLanding.cinematic.trial.steps.${id}.day`),
    label: t(`saasLanding.cinematic.trial.steps.${id}.label`),
    title: t(`saasLanding.cinematic.trial.steps.${id}.title`),
    description: t(`saasLanding.cinematic.trial.steps.${id}.description`),
    bullets: (tm(`saasLanding.cinematic.trial.steps.${id}.bullets`) as any[]).map((b: any) => rt(b))
  }))
})

const trialAssurances = computed(() => [
  { icon: 'lucide:credit-card', label: t('saasLanding.cinematic.trial.assurances.noCard') },
  { icon: 'lucide:x-circle', label: t('saasLanding.cinematic.trial.assurances.cancel') },
  { icon: 'lucide:life-buoy', label: t('saasLanding.cinematic.trial.assurances.support') },
  { icon: 'lucide:shield', label: t('saasLanding.cinematic.trial.assurances.data') }
])

const featureGrid = computed(() => [
  {
    icon: 'lucide:layers',
    title: t('marketing.featuresPage.items.tenancy.title'),
    description: t('marketing.featuresPage.items.tenancy.description')
  },
  {
    icon: 'lucide:languages',
    title: t('marketing.featuresPage.items.localization.title'),
    description: t('marketing.featuresPage.items.localization.description')
  },
  {
    icon: 'lucide:truck',
    title: t('marketing.featuresPage.items.logistics.title'),
    description: t('marketing.featuresPage.items.logistics.description')
  },
  {
    icon: 'lucide:line-chart',
    title: t('marketing.featuresPage.items.analytics.title'),
    description: t('marketing.featuresPage.items.analytics.description')
  },
  {
    icon: 'lucide:credit-card',
    title: t('marketing.featuresPage.items.payments.title'),
    description: t('marketing.featuresPage.items.payments.description')
  },
  {
    icon: 'lucide:smartphone',
    title: t('marketing.featuresPage.items.mobile.title'),
    description: t('marketing.featuresPage.items.mobile.description')
  }
])

const pricingPreview = computed(() =>
  PRICING_PLANS.slice(0, 3).map(plan => {
    const card = pricingPlanCardForUi(plan, 'month')
    return {
      code: plan.code,
      name: t(`pricing.plans.${plan.code}.name`),
      description: t(`pricing.plans.${plan.code}.description`),
      price: card.priceText,
      currency: card.currency,
      period: t('pricing.period.perMonth'),
      cta: t(`pricing.plans.${plan.code}.cta`),
      popular: card.popular,
      features: (card.features || []).slice(0, 4).map(f => f.text)
    }
  })
)

const testimonials = computed<Array<{ quote: string; author: string; role: string }>>(() => {
  const raw = tm('saasLanding.testimonials.items') as any
  if (!Array.isArray(raw)) return []
  return raw.map((item: any) => ({
    quote: rt(item.quote),
    author: rt(item.author),
    role: rt(item.role),
  }))
})
const testimonialsRow1 = computed(() => testimonials.value.slice(0, Math.ceil(testimonials.value.length / 2)))
const testimonialsRow2 = computed(() => testimonials.value.slice(Math.ceil(testimonials.value.length / 2)))

const faqItems = computed<Array<{ q: string; a: string }>>(() => {
  const raw = tm('saasLanding.faq.items') as any
  if (!Array.isArray(raw)) return []
  return raw.map((i: any) => ({ q: rt(i.question), a: rt(i.answer) }))
})
</script>

<template>
  <div :dir="isRtl ? 'rtl' : 'ltr'">
    <!-- ─── Hero ─── -->
    <MarketingCinematicHeroCinematic
      :eyebrow="t('saasLanding.cinematic.hero.eyebrow')"
      :headline-pre="t('saasLanding.cinematic.hero.headlinePre')"
      :headline-accent="t('saasLanding.cinematic.hero.headlineAccent')"
      :headline-post="t('saasLanding.cinematic.hero.headlinePost')"
      :subhead="t('saasLanding.cinematic.hero.subhead')"
      :primary-cta="{ label: t('saasLanding.cinematic.hero.ctaPrimary'), to: '/register' }"
      :secondary-cta="{ label: t('saasLanding.cinematic.hero.ctaSecondary'), to: '/features' }"
      :proof-points="heroProof"
    />

    <!-- ─── Logo cloud ─── -->
    <section class="border-y border-white/[0.04] bg-white/[0.01] py-10">
      <div class="cinematic-container !max-w-[88rem]">
        <p class="cinematic-eyebrow mb-6 text-center">{{ t('saasLanding.cinematic.logoCloud') }}</p>
        <MarketingCinematicLogoCloud :logos="integrationLogos" />
      </div>
    </section>

    <!-- ─── How it works ─── -->
    <MarketingCinematicSectionShell
      :eyebrow="t('saasLanding.storyteller.eyebrow')"
      :title-pre="t('saasLanding.cinematic.howItWorks.titlePre')"
      :title-accent="t('saasLanding.cinematic.howItWorks.titleAccent')"
      :title-post="t('saasLanding.cinematic.howItWorks.titlePost')"
      :description="t('saasLanding.cinematic.howItWorks.description')"
    >
      <div class="grid gap-5 md:grid-cols-2">
        <MarketingCinematicFeatureCard3D
          v-for="card in stepCards"
          :key="card.step"
          v-motion-slide-visible-once-bottom
          :step="card.step"
          :icon="card.icon"
          :title="card.title"
          :description="card.description"
          :bullets="card.bullets"
        />
      </div>
    </MarketingCinematicSectionShell>

    <!-- ─── Live preview ─── -->
    <section class="cinematic-section">
      <div class="cinematic-container">
        <div class="grid items-center gap-10 lg:grid-cols-2">
          <div>
            <span class="cinematic-pill">
              <span class="cinematic-pill__dot" />
              {{ t('saasLanding.cinematic.preview.eyebrow') }}
            </span>
            <h2 class="cinematic-headline mt-6">
              {{ t('saasLanding.cinematic.preview.titlePre') }}
              <em>{{ t('saasLanding.cinematic.preview.titleAccent') }}</em>
              {{ t('saasLanding.cinematic.preview.titlePost') }}
            </h2>
            <p class="cinematic-subhead mt-5">{{ t('saasLanding.cinematic.preview.description') }}</p>
            <div class="mt-7 space-y-3">
              <div v-for="point in [t('saasLanding.cinematic.preview.point1'), t('saasLanding.cinematic.preview.point2'), t('saasLanding.cinematic.preview.point3')]" :key="point" class="flex items-start gap-3 text-[15px] text-[color:var(--m-text)]/85">
                <Icon name="lucide:check-circle-2" class="mt-0.5 h-4 w-4 flex-none text-lime-neon" />
                <span>{{ point }}</span>
              </div>
            </div>
          </div>

          <div v-motion-slide-visible-once-bottom class="cinematic-card relative aspect-[4/3] overflow-hidden p-0">
            <div class="absolute inset-0 bg-gradient-to-br from-[#0A1014] via-[#06181a] to-[#05070A]" />
            <div class="absolute inset-0 cinematic-grid-bg opacity-50" />
            <div class="relative h-full p-5 md:p-7 flex flex-col">
              <div class="flex items-center gap-2 mb-4">
                <span class="h-2.5 w-2.5 rounded-full bg-white/10" />
                <span class="h-2.5 w-2.5 rounded-full bg-white/10" />
                <span class="h-2.5 w-2.5 rounded-full bg-white/10" />
                <div class="ml-3 flex-1 rounded-md bg-white/[0.03] border border-white/[0.05] px-3 py-1 font-mono text-[10px] text-[color:var(--m-text-faint)]">
                  store.swekly.com/admin/orders
                </div>
              </div>
              <div class="flex-1 grid grid-rows-3 gap-3">
                <div v-for="(row, i) in 3" :key="i" class="flex items-center gap-3 rounded-lg border border-white/[0.05] bg-white/[0.015] px-3 py-2.5">
                  <span class="cinematic-mono-num text-xs text-[color:var(--m-text-dim)]">#{{ 1024 + i }}</span>
                  <div class="flex-1 min-w-0">
                    <div class="h-2 w-2/3 rounded bg-white/10" />
                    <div class="mt-1.5 h-1.5 w-1/3 rounded bg-white/[0.06]" />
                  </div>
                  <span class="rounded-full border px-2 py-0.5 text-[10px] font-mono uppercase tracking-wider"
                    :class="i === 0 ? 'border-lime-neon/40 bg-lime-neon/10 text-lime-neon' : 'border-white/[0.08] bg-white/[0.03] text-[color:var(--m-text-dim)]'">
                    {{ i === 0 ? 'NEW' : i === 1 ? 'SHIPPED' : 'PAID' }}
                  </span>
                </div>
              </div>
              <div class="mt-4 flex items-center justify-between rounded-lg border border-lime-neon/30 bg-lime-neon/[0.04] px-3 py-2">
                <span class="font-mono text-[10px] uppercase tracking-[0.2em] text-lime-neon">live</span>
                <span class="cinematic-mono-num text-xs text-white">+ 3 orders / 12s</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ─── Metrics ─── -->
    <section class="cinematic-section border-y border-white/[0.04] bg-gradient-to-b from-transparent via-white/[0.01] to-transparent">
      <div class="cinematic-container">
        <div class="grid gap-10 md:grid-cols-3">
          <MarketingCinematicMetricTile
            v-for="m in metrics"
            :key="m.label"
            :label="m.label"
            :value="m.value"
            :detail="m.detail"
          />
        </div>
      </div>
    </section>

    <!-- ─── Merchant wall ─── -->
    <MarketingCinematicSectionShell
      :eyebrow="t('saasLanding.cinematic.merchants.eyebrow')"
      :title-pre="t('saasLanding.cinematic.merchants.titlePre')"
      :title-accent="t('saasLanding.cinematic.merchants.titleAccent')"
      :title-post="t('saasLanding.cinematic.merchants.titlePost')"
      :description="t('saasLanding.cinematic.merchants.description')"
    >
      <MarketingCinematicMerchantWall :merchants="merchantWall" :metrics="merchantMetrics" />
    </MarketingCinematicSectionShell>

    <!-- ─── Features grid ─── -->
    <MarketingCinematicSectionShell
      :eyebrow="t('saasLanding.cinematic.features.eyebrow')"
      :title-pre="t('saasLanding.cinematic.features.titlePre')"
      :title-accent="t('saasLanding.cinematic.features.titleAccent')"
      :title-post="t('saasLanding.cinematic.features.titlePost')"
      :description="t('saasLanding.cinematic.features.description')"
    >
      <div class="grid gap-5 md:grid-cols-2 lg:grid-cols-3">
        <MarketingCinematicFeatureCard3D
          v-for="f in featureGrid"
          :key="f.title"
          v-motion-slide-visible-once-bottom
          :icon="f.icon"
          :title="f.title"
          :description="f.description"
        />
      </div>
    </MarketingCinematicSectionShell>

    <!-- ─── Theme showcase ─── -->
    <MarketingCinematicSectionShell
      :eyebrow="t('saasLanding.cinematic.templates.eyebrow')"
      :title-pre="t('saasLanding.cinematic.templates.titlePre')"
      :title-accent="t('saasLanding.cinematic.templates.titleAccent')"
      :title-post="t('saasLanding.cinematic.templates.titlePost')"
      :description="t('saasLanding.cinematic.templates.description')"
    >
      <MarketingCinematicThemeShowcase :themes="themeShowcase" />
      <div class="mt-10 text-center">
        <NuxtLink to="/themes" class="cinematic-link inline-flex items-center gap-2 text-sm">
          {{ t('saasLanding.cinematic.templates.viewAll') }}
          <Icon name="lucide:arrow-right" class="h-4 w-4" />
        </NuxtLink>
      </div>
    </MarketingCinematicSectionShell>

    <!-- ─── Pricing preview ─── -->
    <MarketingCinematicSectionShell
      :eyebrow="t('saasLanding.cinematic.pricing.eyebrow')"
      :title-pre="t('saasLanding.cinematic.pricing.titlePre')"
      :title-accent="t('saasLanding.cinematic.pricing.titleAccent')"
      :title-post="t('saasLanding.cinematic.pricing.titlePost')"
      :description="t('saasLanding.cinematic.pricing.description')"
      centered
    >
      <div class="grid gap-5 md:grid-cols-3">
        <MarketingCinematicPricingTile
          v-for="plan in pricingPreview"
          :key="plan.code"
          v-motion-slide-visible-once-bottom
          :name="plan.name"
          :price="plan.price"
          :currency="plan.currency"
          :period="plan.period"
          :description="plan.description"
          :features="plan.features"
          :cta="plan.cta"
          :cta-to="`/pricing#${plan.code}`"
          :featured="plan.popular"
          :popular-label="t('pricing.popular')"
        />
      </div>
      <div class="mt-10 text-center">
        <NuxtLink to="/pricing" class="cinematic-link inline-flex items-center gap-2 text-sm">
          {{ t('saasLanding.cinematic.pricing.viewAll') }}
          <Icon name="lucide:arrow-right" class="h-4 w-4" />
        </NuxtLink>
      </div>
    </MarketingCinematicSectionShell>

    <!-- ─── Testimonials ─── -->
    <section v-if="testimonials.length" class="cinematic-section">
      <div class="cinematic-container">
        <div class="mb-12 max-w-3xl">
          <span class="cinematic-pill">
            <span class="cinematic-pill__dot" />
            {{ t('saasLanding.testimonials.eyebrow') }}
          </span>
          <h2 class="cinematic-headline mt-6">
            {{ t('saasLanding.cinematic.testimonials.titlePre') }}
            <em>{{ t('saasLanding.cinematic.testimonials.titleAccent') }}</em>
            {{ t('saasLanding.cinematic.testimonials.titlePost') }}
          </h2>
        </div>
      </div>

      <div class="space-y-5">
        <MarketingCinematicMarquee :duration="55">
          <div v-for="(item, i) in testimonialsRow1" :key="`r1-${i}`" class="mx-3 w-[340px] flex-none cinematic-card p-6">
            <Icon name="lucide:quote" class="h-5 w-5 text-lime-neon" />
            <p class="mt-3 text-[15px] leading-relaxed text-white/90">{{ item.quote }}</p>
            <div class="mt-5 border-t border-white/5 pt-4">
              <p class="text-sm font-medium text-white">{{ item.author }}</p>
              <p class="text-xs text-[color:var(--m-text-dim)]">{{ item.role }}</p>
            </div>
          </div>
        </MarketingCinematicMarquee>
        <MarketingCinematicMarquee :duration="55" direction="reverse">
          <div v-for="(item, i) in testimonialsRow2" :key="`r2-${i}`" class="mx-3 w-[340px] flex-none cinematic-card p-6">
            <Icon name="lucide:quote" class="h-5 w-5 text-lime-neon" />
            <p class="mt-3 text-[15px] leading-relaxed text-white/90">{{ item.quote }}</p>
            <div class="mt-5 border-t border-white/5 pt-4">
              <p class="text-sm font-medium text-white">{{ item.author }}</p>
              <p class="text-xs text-[color:var(--m-text-dim)]">{{ item.role }}</p>
            </div>
          </div>
        </MarketingCinematicMarquee>
      </div>
    </section>

    <!-- ─── FAQ ─── -->
    <MarketingCinematicSectionShell
      v-if="faqItems.length"
      :eyebrow="t('saasLanding.faq.eyebrow')"
      :title-pre="t('saasLanding.cinematic.faq.titlePre')"
      :title-accent="t('saasLanding.cinematic.faq.titleAccent')"
      :title-post="t('saasLanding.cinematic.faq.titlePost')"
    >
      <div class="mx-auto max-w-3xl">
        <MarketingCinematicFAQAccordion :items="faqItems" />
      </div>
    </MarketingCinematicSectionShell>

    <!-- ─── Trial timeline ─── -->
    <MarketingCinematicSectionShell
      :eyebrow="t('saasLanding.cinematic.trial.eyebrow')"
      :title-pre="t('saasLanding.cinematic.trial.titlePre')"
      :title-accent="t('saasLanding.cinematic.trial.titleAccent')"
      :title-post="t('saasLanding.cinematic.trial.titlePost')"
      :description="t('saasLanding.cinematic.trial.description')"
      centered
    >
      <MarketingCinematicTrialTimeline
        :steps="trialSteps"
        :finish-label="t('saasLanding.cinematic.trial.finishLabel')"
        :assurances="trialAssurances"
      />
    </MarketingCinematicSectionShell>

    <!-- ─── Final CTA ─── -->
    <MarketingCinematicCTABand
      :eyebrow="t('saasLanding.cinematic.cta.eyebrow')"
      :headline-pre="t('saasLanding.cinematic.cta.headlinePre')"
      :headline-accent="t('saasLanding.cinematic.cta.headlineAccent')"
      :headline-post="t('saasLanding.cinematic.cta.headlinePost')"
      :subhead="t('saasLanding.cinematic.cta.subhead')"
      :primary-cta="{ label: t('saasLanding.cinematic.cta.button'), to: '/register' }"
      :secondary-cta="{ label: t('saasLanding.cinematic.cta.secondary'), to: '/contact' }"
    />
  </div>
</template>
