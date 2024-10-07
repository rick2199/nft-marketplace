"use client"

import { useAccount, useBalance, useEnsName } from "wagmi"
import { middleEllipsis } from "../lib/utils"
import { formatUnits } from "viem"

export default function Profile() {
  const { address, chain } = useAccount()

  const { data } = useBalance({
    address,
  })

  const ens = useEnsName({
    address,
  })

  return (
    <div className="ui-mb-32 ui-grid ui-text-center lg:ui-max-w-5xl lg:ui-w-full lg:ui-mb-0 lg:ui-grid-cols-4 lg:ui-text-left">
      <div className="ui-group ui-rounded-lg ui-border ui-border-transparent ui-px-5 ui-py-4 ui-transition-colors hover:ui-border-gray-300 hover:ui-bg-gray-100 hover:dark:ui-border-neutral-700 hover:dark:ui-bg-neutral-800/30">
        <h2 className="ui-mb-3 ui-text-2xl ui-font-semibold">Wallet address</h2>
        <p className="ui-m-0 ui-w-[30ch] ui-text-sm ui-opacity-50">
          {middleEllipsis(address as string, 12) || ""}
        </p>
      </div>

      <div className="ui-group ui-rounded-lg ui-border ui-border-transparent ui-px-5 ui-py-4 ui-transition-colors hover:ui-border-gray-300 hover:ui-bg-gray-100 hover:dark:ui-border-neutral-700 hover:dark:ui-bg-neutral-800/30">
        <h2 className={`ui-mb-3 ui-text-2xl ui-font-semibold`}>Network</h2>
        <p className={`ui-m-0 ui-max-w-[30ch] ui-text-sm ui-opacity-50`}>
          {chain?.name || ""}
        </p>
      </div>

      <div className="ui-group ui-rounded-lg ui-border ui-border-transparent ui-px-5 ui-py-4 ui-transition-colors hover:ui-border-gray-300 hover:ui-bg-gray-100 hover:dark:ui-border-neutral-700 hover:dark:ui-bg-neutral-800/30">
        <h2 className={`ui-mb-3 ui-text-2xl ui-font-semibold`}>Balance</h2>
        <div className={`ui-m-0 ui-max-w-[30ch] ui-text-sm ui-opacity-50`}>
          {data ? (
            <p>
              {Number(formatUnits(data.value, data.decimals)).toFixed(4)}{" "}
              {data.symbol}
            </p>
          ) : (
            <div />
          )}
        </div>
      </div>

      <div className="ui-group ui-rounded-lg ui-border ui-border-transparent ui-px-5 ui-py-4 ui-transition-colors hover:ui-border-gray-300 hover:ui-bg-gray-100 hover:dark:ui-border-neutral-700 hover:dark:ui-bg-neutral-800/30">
        <h2 className={`ui-mb-3 ui-text-2xl ui-font-semibold`}>EnsName</h2>
        <p
          className={`ui-m-0 ui-max-w-[30ch] ui-text-sm ui-opacity-50 ui-text-balance`}
        >
          {ens.data || ""}
        </p>
      </div>
    </div>
  )
}
