import { useContext } from "react";
import { NFTMarketContext } from "../../context/__generated__/SymfoniContext";
import { ContractsContext } from "../../context/ContractsProvider";

export const useNFTMarketContract = () => {
  const contract = useContext(NFTMarketContext);
  const addresses = useContext(ContractsContext);
  let instance = contract.instance;

  if (!addresses) {
    throw new Error(
      "No addresses found. Make sure you are using the ContractsProvider"
    );
  }

  if (contract.instance) {
    instance = contract.instance.attach(addresses.nftMarketAddress);
  }

  return instance;
};
