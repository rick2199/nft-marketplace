"use client"

import { useEffect, useRef } from "react"
import {
  useConnectModal,
  useAccountModal,
  useChainModal,
} from "@rainbow-me/rainbowkit"
import { useAccount, useDisconnect } from "wagmi"
import { emojiAvatarForAddress } from "../lib/emojiAvatarForAddress"

export default function ConnectButton() {
  const { isConnecting, address, isConnected, chain } = useAccount()
  const { color: backgroundColor, emoji } = emojiAvatarForAddress(address ?? "")

  const { openConnectModal } = useConnectModal()
  const { openAccountModal } = useAccountModal()
  const { openChainModal } = useChainModal()
  const { disconnect } = useDisconnect()

  const isMounted = useRef(false)

  useEffect(() => {
    isMounted.current = true
  }, [])

  if (!isConnected) {
    return (
      <button
        className="ui-btn"
        onClick={async () => {
          // Disconnecting wallet first because sometimes when is connected but the user is not connected
          if (isConnected) {
            disconnect()
          }
          openConnectModal?.()
        }}
        disabled={isConnecting}
      >
        {isConnecting ? "Connecting..." : "Connect your wallet"}
      </button>
    )
  }

  if (isConnected && !chain) {
    return (
      <button className="ui-btn" onClick={openChainModal}>
        Wrong network
      </button>
    )
  }

  return (
    <div className="ui-max-w-5xl ui-w-full ui-flex ui-items-center ui-justify-between">
      <div
        className="ui-flex ui-justify-center ui-items-center ui-px-4 ui-py-2 ui-border ui-border-neutral-700 ui-bg-neutral-800/30 ui-rounded-xl ui-font-mono ui-font-bold ui-gap-x-2 ui-cursor-pointer"
        onClick={async () => openAccountModal?.()}
      >
        <div
          role="button"
          tabIndex={1}
          className="ui-h-8 ui-w-8 ui-rounded-full ui-flex ui-items-center ui-justify-center ui-flex-shrink-0 ui-overflow-hidden"
          style={{
            backgroundColor,
            boxShadow: "0px 2px 2px 0px rgba(81, 98, 255, 0.20)",
          }}
        >
          {emoji}
        </div>
        <p>Account</p>
      </div>
      <button className="ui-btn" onClick={openChainModal}>
        Switch Networks
      </button>
    </div>
  )
}
