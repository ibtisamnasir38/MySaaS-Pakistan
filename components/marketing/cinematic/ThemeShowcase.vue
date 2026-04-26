<template>
  <div class="theme-showcase grid gap-5 md:grid-cols-2 lg:grid-cols-3">
    <NuxtLink
      v-for="theme in themes"
      :key="theme.id"
      v-motion-slide-visible-once-bottom
      :to="theme.to"
      class="theme-card cinematic-card group relative overflow-hidden p-0"
    >
      <div class="theme-card__preview" :class="`theme-card__preview--${theme.id}`">
        <div class="theme-card__chrome">
          <span class="theme-card__dot" />
          <span class="theme-card__dot" />
          <span class="theme-card__dot" />
          <div class="theme-card__url">{{ theme.urlSlug }}.swekly.com</div>
        </div>

        <div class="theme-card__viewport">
          <div class="theme-card__brand" :style="{ fontFamily: theme.brandFont }">{{ theme.brand }}</div>
          <div class="theme-card__hero">
            <div class="theme-card__heroTitle" />
            <div class="theme-card__heroSub" />
            <div class="theme-card__cta" />
          </div>
          <div class="theme-card__grid">
            <div v-for="i in 3" :key="i" class="theme-card__tile">
              <div class="theme-card__tileImg" />
              <div class="theme-card__tileLine" />
            </div>
          </div>
        </div>
      </div>

      <div class="theme-card__meta">
        <div class="flex items-center justify-between gap-3">
          <h3 class="text-base font-medium tracking-tight text-white">{{ theme.name }}</h3>
          <span class="theme-card__badge">{{ theme.category }}</span>
        </div>
        <p class="mt-2 text-sm text-[color:var(--m-text-dim)]">{{ theme.tagline }}</p>
        <div class="mt-4 flex items-center gap-1.5 text-xs font-mono uppercase tracking-[0.2em] text-lime-neon opacity-0 transition-opacity duration-300 group-hover:opacity-100">
          <span>preview</span>
          <Icon name="lucide:arrow-up-right" class="h-3.5 w-3.5" />
        </div>
      </div>
    </NuxtLink>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  themes: Array<{
    id: string
    name: string
    category: string
    tagline: string
    brand: string
    brandFont: string
    urlSlug: string
    to: string
  }>
}>()
</script>

<style scoped>
.theme-card {
  display: flex;
  flex-direction: column;
  transition: transform 0.4s cubic-bezier(0.2, 0.8, 0.2, 1);
}
.theme-card:hover {
  transform: translateY(-4px);
}

.theme-card__preview {
  position: relative;
  aspect-ratio: 16 / 11;
  overflow: hidden;
  border-bottom: 1px solid rgba(255, 255, 255, 0.05);
  padding: 12px;
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.theme-card__chrome {
  display: flex;
  align-items: center;
  gap: 5px;
}

.theme-card__dot {
  display: block;
  width: 7px;
  height: 7px;
  border-radius: 9999px;
  background: rgba(255, 255, 255, 0.18);
}

.theme-card__url {
  margin-left: 8px;
  flex: 1;
  font-family: ui-monospace, SFMono-Regular, monospace;
  font-size: 9px;
  padding: 4px 8px;
  border-radius: 5px;
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid rgba(255, 255, 255, 0.06);
  color: rgba(255, 255, 255, 0.5);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.theme-card__viewport {
  flex: 1;
  border-radius: 8px;
  padding: 14px;
  display: flex;
  flex-direction: column;
  gap: 10px;
  overflow: hidden;
  position: relative;
}

.theme-card__brand {
  font-size: 14px;
  font-weight: 600;
  letter-spacing: -0.01em;
}

.theme-card__hero {
  display: flex;
  flex-direction: column;
  gap: 6px;
  padding: 8px 0;
}

.theme-card__heroTitle {
  height: 8px;
  width: 75%;
  border-radius: 3px;
  background: currentColor;
  opacity: 0.85;
}

.theme-card__heroSub {
  height: 4px;
  width: 50%;
  border-radius: 3px;
  background: currentColor;
  opacity: 0.45;
}

.theme-card__cta {
  margin-top: 4px;
  height: 14px;
  width: 60px;
  border-radius: 4px;
  background: currentColor;
  opacity: 0.95;
}

.theme-card__grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 6px;
  flex: 1;
}

.theme-card__tile {
  border-radius: 5px;
  background: rgba(255, 255, 255, 0.06);
  padding: 5px;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.theme-card__tileImg {
  flex: 1;
  border-radius: 3px;
  background: currentColor;
  opacity: 0.18;
}

.theme-card__tileLine {
  height: 3px;
  width: 60%;
  border-radius: 2px;
  background: currentColor;
  opacity: 0.55;
}

.theme-card__meta {
  padding: 18px 22px 22px;
}

.theme-card__badge {
  font-family: ui-monospace, SFMono-Regular, monospace;
  font-size: 9px;
  letter-spacing: 0.18em;
  text-transform: uppercase;
  padding: 3px 8px;
  border-radius: 9999px;
  border: 1px solid rgba(255, 255, 255, 0.08);
  background: rgba(255, 255, 255, 0.025);
  color: rgba(255, 255, 255, 0.65);
}

/* Per-theme palettes */
.theme-card__preview--minimal {
  background: linear-gradient(180deg, #f5f4f1 0%, #e8e6e0 100%);
  color: #18181b;
}
.theme-card__preview--minimal .theme-card__viewport { background: #ffffff; }
.theme-card__preview--minimal .theme-card__cta { background: #18181b; }

.theme-card__preview--modern {
  background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
  color: #f8fafc;
}
.theme-card__preview--modern .theme-card__viewport { background: #0a1019; }
.theme-card__preview--modern .theme-card__cta { background: #6366f1; opacity: 1; }

.theme-card__preview--cyber {
  background: linear-gradient(135deg, #0a0a0a 0%, #1a0d2e 100%);
  color: #d4ff66;
}
.theme-card__preview--cyber .theme-card__viewport {
  background: #050308;
  background-image: linear-gradient(rgba(212,255,102,.04) 1px, transparent 1px), linear-gradient(90deg, rgba(212,255,102,.04) 1px, transparent 1px);
  background-size: 14px 14px;
}
.theme-card__preview--cyber .theme-card__cta { background: #d4ff66; opacity: 1; }

.theme-card__preview--food {
  background: linear-gradient(135deg, #fff7ed 0%, #fed7aa 100%);
  color: #7c2d12;
}
.theme-card__preview--food .theme-card__viewport { background: #fffbf5; }
.theme-card__preview--food .theme-card__cta { background: #ea580c; color: #fff; opacity: 1; }

.theme-card__preview--classic {
  background: linear-gradient(180deg, #f9f5ee 0%, #ede5d3 100%);
  color: #2d1810;
}
.theme-card__preview--classic .theme-card__viewport { background: #fdfaf3; }
.theme-card__preview--classic .theme-card__cta { background: #2d1810; opacity: 1; }

.theme-card__preview--cozy {
  background: linear-gradient(135deg, #fdf2f8 0%, #fce7f3 100%);
  color: #831843;
}
.theme-card__preview--cozy .theme-card__viewport { background: #fffafc; }
.theme-card__preview--cozy .theme-card__cta { background: #be185d; opacity: 1; }
</style>
