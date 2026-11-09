<script setup lang="ts">
/** The data behind a chart, as a table (a11y: the chart is never the only way to read it). */
defineProps<{ columns: string[]; rows: (string | number | null)[][] }>()
</script>

<template>
  <details class="mt-2 text-xs text-muted-foreground">
    <summary class="cursor-pointer select-none hover:text-foreground">Data table</summary>
    <div class="mt-2 max-h-64 overflow-auto rounded-md border">
      <table class="w-full text-left tabular-nums">
        <thead class="sticky top-0 bg-muted">
          <tr><th v-for="c in columns" :key="c" class="px-2 py-1 font-medium">{{ c }}</th></tr>
        </thead>
        <tbody>
          <tr v-for="(row, i) in rows" :key="i" class="border-t">
            <td v-for="(cell, j) in row" :key="j" class="px-2 py-1 text-foreground">{{ cell ?? '—' }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </details>
</template>
