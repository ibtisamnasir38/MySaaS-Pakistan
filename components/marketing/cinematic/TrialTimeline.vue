<template>
  <div class="trial-timeline">
    <div class="trial-timeline__rail" aria-hidden="true">
      <div class="trial-timeline__rail-progress" />
    </div>

    <div class="trial-timeline__steps">
      <div
        v-for="(step, i) in steps"
        :key="step.label"
        v-motion-slide-visible-once-bottom
        class="trial-timeline__step"
      >
        <div class="trial-timeline__node">
          <span class="trial-timeline__nodeRing" />
          <span class="trial-timeline__nodeDot" />
        </div>

        <div class="cinematic-card trial-timeline__card">
          <div class="trial-timeline__day">
            <span class="cinematic-mono-num">{{ step.day }}</span>
            <span class="trial-timeline__dayLabel">{{ step.label }}</span>
          </div>
          <h3 class="mt-4 text-lg font-medium tracking-tight text-white">{{ step.title }}</h3>
          <p class="mt-2 text-sm leading-relaxed text-[color:var(--m-text-dim)]">{{ step.description }}</p>

          <ul v-if="step.bullets?.length" class="mt-4 space-y-2 border-t border-white/5 pt-4">
            <li v-for="bullet in step.bullets" :key="bullet" class="flex items-start gap-2.5 text-[13px] text-[color:var(--m-text)]/85">
              <Icon name="lucide:check" class="mt-0.5 h-3.5 w-3.5 flex-none text-lime-neon" />
              <span>{{ bullet }}</span>
            </li>
          </ul>

          <div v-if="i === steps.length - 1" class="trial-timeline__finish">
            <Icon name="lucide:sparkles" class="h-3.5 w-3.5" />
            {{ finishLabel }}
          </div>
        </div>
      </div>
    </div>

    <div class="trial-timeline__assurance">
      <div v-for="item in assurances" :key="item.label" class="trial-timeline__assurance-item">
        <Icon :name="item.icon" class="h-4 w-4 text-lime-neon" />
        <span>{{ item.label }}</span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  steps: Array<{
    day: string
    label: string
    title: string
    description: string
    bullets?: string[]
  }>
  finishLabel: string
  assurances: Array<{ icon: string; label: string }>
}>()
</script>

<style scoped>
.trial-timeline {
  position: relative;
}

.trial-timeline__rail {
  display: none;
  position: absolute;
  top: 18px;
  left: 5%;
  right: 5%;
  height: 1px;
  background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.08) 10%, rgba(255, 255, 255, 0.08) 90%, transparent);
  z-index: 0;
}

.trial-timeline__rail-progress {
  position: absolute;
  inset: 0;
  background: linear-gradient(90deg, var(--lime-neon, #d4ff66), transparent);
  width: 35%;
  filter: blur(0.5px);
}

@media (min-width: 1024px) {
  .trial-timeline__rail {
    display: block;
  }
}

.trial-timeline__steps {
  position: relative;
  display: grid;
  gap: 1.25rem;
  z-index: 1;
}

@media (min-width: 1024px) {
  .trial-timeline__steps {
    grid-template-columns: repeat(4, 1fr);
    gap: 1rem;
  }
}

.trial-timeline__step {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
  align-items: stretch;
}

.trial-timeline__node {
  position: relative;
  width: 36px;
  height: 36px;
  align-self: flex-start;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.trial-timeline__nodeRing {
  position: absolute;
  inset: 0;
  border-radius: 9999px;
  border: 1px solid rgba(212, 255, 102, 0.2);
  background: rgba(212, 255, 102, 0.04);
  backdrop-filter: blur(4px);
}

.trial-timeline__nodeDot {
  width: 8px;
  height: 8px;
  border-radius: 9999px;
  background: var(--lime-neon, #d4ff66);
  box-shadow: 0 0 12px rgba(212, 255, 102, 0.6);
  position: relative;
}

.trial-timeline__card {
  flex: 1;
  padding: 1.5rem;
  display: flex;
  flex-direction: column;
}

.trial-timeline__day {
  display: flex;
  align-items: baseline;
  gap: 0.5rem;
}

.trial-timeline__day .cinematic-mono-num {
  font-size: 22px;
  color: var(--lime-neon, #d4ff66);
  letter-spacing: -0.02em;
}

.trial-timeline__dayLabel {
  font-family: ui-monospace, SFMono-Regular, monospace;
  font-size: 10px;
  letter-spacing: 0.22em;
  text-transform: uppercase;
  color: rgba(255, 255, 255, 0.4);
}

.trial-timeline__finish {
  margin-top: 1.25rem;
  display: inline-flex;
  align-self: flex-start;
  align-items: center;
  gap: 0.4rem;
  padding: 0.4rem 0.75rem;
  border-radius: 9999px;
  border: 1px solid rgba(212, 255, 102, 0.3);
  background: rgba(212, 255, 102, 0.06);
  font-family: ui-monospace, SFMono-Regular, monospace;
  font-size: 10px;
  letter-spacing: 0.18em;
  text-transform: uppercase;
  color: var(--lime-neon, #d4ff66);
}

.trial-timeline__assurance {
  margin-top: 3rem;
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: 1rem 2rem;
  padding-top: 2rem;
  border-top: 1px solid rgba(255, 255, 255, 0.04);
}

.trial-timeline__assurance-item {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 13px;
  color: rgba(255, 255, 255, 0.7);
}
</style>
