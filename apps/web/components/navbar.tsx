"use client"
import Image from "next/image"
import React, { useState } from "react"
import {
  DropdownMenu,
  DropdownMenuTrigger,
  DropdownMenuContent,
  DropdownMenuItem,
} from "@nft-marketplace/ui/components/ui/dropdown-menu"

import { middleEllipsis } from "../lib/wagmi/utils"
import { emojiAvatarForAddress } from "../lib/wagmi/emojiAvatarForAddress"
import { useAccount, useDisconnect } from "wagmi"
import { useChainModal, useConnectModal } from "@rainbow-me/rainbowkit"
import Link from "next/link"
import { Button } from "@nft-marketplace/ui/components/ui/button"

interface NavItem {
  label: string
  href: string
  current?: boolean
}

const navItems: NavItem[] = [
  { label: "Explore", href: "#", current: true },
  { label: "Create Item", href: "#" },
]

export default function Navbar() {
  const [isMenuOpen, setIsMenuOpen] = useState(false)
  const [copyText, setCopyText] = useState("Copy Address")
  const [disconnectText, setDisconnectText] = useState("Disconnect")
  const { isConnecting, address, isConnected, chain } = useAccount()
  const { openConnectModal } = useConnectModal()
  const { disconnect } = useDisconnect()
  const isProfileMenuDisabled = !address || !chain
  const { color: backgroundColor, emoji } = emojiAvatarForAddress(address ?? "")
  const { openChainModal } = useChainModal()
  console.log({ backgroundColor })
  const handleCopyAddress = () => {
    if (address) {
      navigator.clipboard.writeText(address)
    }
  }

  const handleDisconnect = (
    e: React.MouseEvent<HTMLDivElement, MouseEvent>
  ) => {
    e.preventDefault()
    setDisconnectText("Disconnecting...")
    setTimeout(() => {
      disconnect()
      setDisconnectText("Disconnected ✔️")
      setTimeout(() => {
        setDisconnectText("Disconnect")
      }, 1000)
    }, 1000)
  }

  if (isConnected && !chain) {
    return (
      <button className="btn" onClick={openChainModal}>
        Wrong network
      </button>
    )
  }

  return (
    <nav className="bg-white border-gray-200 dark:bg-gray-900">
      <div className="max-w-screen-xl flex flex-wrap items-center justify-between mx-auto p-4">
        <Link
          href="/"
          className="flex items-center space-x-3 rtl:space-x-reverse"
        >
          <Image
            src="https://cdn.vectorstock.com/i/1000x1000/23/04/marketplace-icon-nft-related-vector-41202304.webp"
            className="h-8"
            alt="Flowbite Logo"
            width={32}
            height={32}
          />
          <span className="self-center text-2xl font-semibold whitespace-nowrap dark:text-white">
            NFT Marketplace
          </span>
        </Link>
        <div className="flex items-center gap-x-10 md:order-2 space-x-3 md:space-x-0 rtl:space-x-reverse">
          <ul className="flex flex-col font-medium p-4 md:p-0 mt-4 border border-gray-100 rounded-lg bg-gray-50 md:space-x-8 rtl:space-x-reverse md:flex-row md:mt-0 md:border-0 md:bg-white dark:bg-gray-800 md:dark:bg-gray-900 dark:border-gray-700">
            {navItems.map((item) => (
              <li key={item.label}>
                <a
                  href={item.href}
                  className={`block py-2 px-3 text-gray-900 rounded md:bg-transparent md:p-0 dark:text-white md:dark:hover:text-blue-500 ${
                    item.current
                      ? "bg-blue-700 text-white md:text-blue-700 dark:text-blue-500"
                      : "hover:bg-gray-100 dark:hover:bg-gray-700"
                  }`}
                  aria-current={item.current ? "page" : undefined}
                >
                  {item.label}
                </a>
              </li>
            ))}
          </ul>
          {!chain && (
            <Button
              variant={"default"}
              color="primary"
              onClick={async () => {
                // Disconnecting wallet first because sometimes when is connected but the user is not connected
                if (isConnected) {
                  disconnect()
                }
                openConnectModal?.()
              }}
            >
              {isConnecting ? "Connecting..." : "Connect your wallet"}
            </Button>
          )}
          {isConnected && !chain && (
            <Button variant={"default"} onClick={openChainModal}>
              Wrong network
            </Button>
          )}
          {chain && isConnected && (
            <DropdownMenu>
              <DropdownMenuTrigger disabled={isProfileMenuDisabled} asChild>
                <div
                  className="flex items-center justify-center w-10 h-10 bg-gray-800 rounded-full focus:ring-4 focus:ring-gray-300 dark:focus:ring-gray-600"
                  role="button"
                  aria-label="Open user menu"
                  style={{ background: backgroundColor }}
                >
                  <span className="text-lg">{emoji ?? "🦄"}</span>
                </div>
              </DropdownMenuTrigger>
              <DropdownMenuContent className="absolute right-0 mt-2 w-48 bg-white rounded-lg shadow-lg dark:bg-gray-700">
                <div className="px-4 py-3">
                  <span className="block text-sm text-gray-900 dark:text-white">
                    {middleEllipsis(address as string, 8) || ""}
                  </span>
                  <span className="block text-sm text-gray-500 truncate dark:text-gray-400">
                    {chain?.name} Network
                  </span>
                </div>
                <ul className="py-2">
                  <DropdownMenuItem
                    className="cursor-pointer"
                    onClick={(e) => {
                      e.preventDefault()
                      handleCopyAddress()
                      setCopyText("Copied! ✔️")
                      setTimeout(() => {
                        setCopyText("Copy Address")
                      }, 1000)
                    }}
                  >
                    <span className="block px-4 w-full py-2 text-sm text-gray-700 hover:bg-gray-100 dark:hover:bg-gray-600 dark:text-gray-200 dark:hover:text-white">
                      {copyText}
                    </span>
                  </DropdownMenuItem>
                  <DropdownMenuItem
                    className="cursor-pointer"
                    onClick={openChainModal}
                  >
                    <span className="block px-4 w-full py-2 text-sm text-gray-700 hover:bg-gray-100 dark:hover:bg-gray-600 dark:text-gray-200 dark:hover:text-white">
                      Switch Network
                    </span>
                  </DropdownMenuItem>
                  <DropdownMenuItem
                    className="cursor-pointer"
                    onClick={(e) => handleDisconnect(e)}
                  >
                    <span className="block px-4 w-full py-2 text-sm text-gray-700 hover:bg-gray-100 dark:hover:bg-gray-600 dark:text-gray-200 dark:hover:text-white">
                      {disconnectText}
                    </span>
                  </DropdownMenuItem>
                </ul>
              </DropdownMenuContent>
            </DropdownMenu>
          )}
          <button
            className="inline-flex items-center p-2 w-10 h-10 justify-center text-sm text-gray-500 rounded-lg md:hidden hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-gray-200 dark:text-gray-400 dark:hover:bg-gray-700 dark:focus:ring-gray-600"
            onClick={() => setIsMenuOpen(!isMenuOpen)}
          >
            <span className="sr-only">Open main menu</span>
            <svg
              className="w-5 h-5"
              aria-hidden="true"
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 17 14"
            >
              <path
                stroke="currentColor"
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth="2"
                d="M1 1h15M1 7h15M1 13h15"
              />
            </svg>
          </button>
        </div>
      </div>
    </nav>
  )
}
