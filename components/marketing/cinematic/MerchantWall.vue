<template>
  <div class="merchant-wall">
    <div class="merchant-wall__grid">
      <div
        v-for="m in merchants"
        :key="m.name"
        v-motion-slide-visible-once-bottom
        class="merchant-wall__cell"
        :title="m.name"
      >
        <div class="merchant-wall__mark" :style="{ background: m.gradient, fontFamily: m.font }">
          <span>{{ m.mark }}</span>
        </div>
        <div class="merchant-wall__info">
          <div class="merchant-wall__name">{{ m.name }}</div>
          <div class="merchant-wall__category">{{ m.category }}</div>
        </div>
      </div>
    </div>

    <div class="merchant-wall__metrics">
      <div v-for="metric in metrics" :key="metric.label" class="merchant-wall__metric">
        <div class="cinematic-mono-num text-2xl font-medium text-white">{{ metric.value }}</div>
        <div class="text-xs uppercase tracking-[0.2em] text-[color:var(--m-text-faint)]">{{ metric.label }}</div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  merchants: Array<{
    name: string
    category: string
    mark: string
    gradient: string
    font: string
  }>
  metrics: Array<{
    value: string
    label: string
  }>
}>()
</script>

<style scoped>
.merchant-wall {
  display: flex;
  flex-direction: column;
  gap: 2rem;
}

.merchant-wall__grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 1px;
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid rgba(255, 255, 255, 0.04);
  border-radius: 16px;
  overflow: hidden;
}

@media (min-width: 640px) {
  .merchant-wall__grid {
    grid-template-columns: repeat(3, 1fr);
  }
}

@media (min-width: 1024px) {
  .merchant-wall__grid {
    grid-template-columns: repeat(4, 1fr);
  }
}

.merchant-wall__cell {
  background: var(--m-bg, #05070A);
  padding: 1.75rem 1.5rem;
  display: flex;
  flex-direction: column;
  gap: 1rem;
  align-items: flex-start;
  transition: background 0.3s ease;
  position: relative;
}

.merchant-wall__cell:hover {
  background: rgba(255, 255, 255, 0.018);
}

.merchant-wall__cell::after {
  content: '';
  position: absolute;
  inset: 0;
  background: linear-gradient(135deg, transparent 60%, rgba(212, 255, 102, 0.05) 100%);
  opacity: 0;
  transition: opacity 0.3s ease;
  pointer-events: none;
}

.merchant-wall__cell:hover::after {
  opacity: 1;
}

.merchant-wall__mark {
  width: 44px;
  height: 44px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 18px;
  font-weight: 700;
  letter-spacing: -0.02em;
  color: #fff;
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.2);
  position: relative;
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.1), 0 4px 12px rgba(0, 0, 0, 0.2);
}

.merchant-wall__info {
  min-width: 0;
}

.merchant-wall__name {
  font-size: 14px;
  font-weight: 500;
  color: rgba(255, 255, 255, 0.95);
  letter-spacing: -0.01em;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.merchant-wall__category {
  margin-top: 2px;
  font-size: 11px;
  font-family: ui-monospace, SFMono-Regular, monospace;
  text-transform: uppercase;
  letter-spacing: 0.16em;
  color: rgba(255, 255, 255, 0.4);
}

.merchant-wall__metrics {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 1.5rem;
  padding: 1.5rem 0;
  border-top: 1px solid rgba(255, 255, 255, 0.04);
}

.merchant-wall__metric {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  align-items: flex-start;
}
</style>
