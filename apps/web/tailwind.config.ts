import type { Config } from "tailwindcss"
import config from "@nft-marketplace/ui/tailwind.config"

const webConfig = {
  ...config,
  presets: [config],
  theme: {
    extend: {},
  },
} satisfies Config

export default webConfig
