"use client"

import { http, createStorage, cookieStorage } from "wagmi"
import { sepolia, bscTestnet } from "wagmi/chains"
import { Chain, getDefaultConfig } from "@rainbow-me/rainbowkit"

const projectId = "285f4d68-0881-4738-b63a-29581113b921"

const supportedChains: Chain[] = [sepolia, bscTestnet]

export const config = getDefaultConfig({
  appName: "WalletConnection",
  projectId,
  chains: supportedChains as any,
  ssr: true,
  storage: createStorage({
    storage: cookieStorage,
  }),
  transports: supportedChains.reduce(
    (obj, chain) => ({ ...obj, [chain.id]: http() }),
    {}
  ),
})
