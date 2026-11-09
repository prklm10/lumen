import type { Component } from 'vue'
import {
  BookOpen, Briefcase, Code, Coffee, Dumbbell, GraduationCap, Heart, House, Lightbulb, Music, Palette, Plane, Rocket,
  ShoppingCart, Target, Wallet,
} from '@lucide/vue'

/** Icons a project can use, stored by their kebab-case Lucide name (projects.icon). */
export const projectIcons: Record<string, Component> = {
  'book-open': BookOpen,
  briefcase: Briefcase,
  code: Code,
  'graduation-cap': GraduationCap,
  lightbulb: Lightbulb,
  target: Target,
  rocket: Rocket,
  heart: Heart,
  dumbbell: Dumbbell,
  house: House,
  'shopping-cart': ShoppingCart,
  wallet: Wallet,
  plane: Plane,
  music: Music,
  palette: Palette,
  coffee: Coffee,
}
