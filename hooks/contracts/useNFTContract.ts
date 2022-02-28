import { useContext } from "react";
import { NFTContext } from "../../context/__generated__/SymfoniContext";
import { ContractsContext } from "../../context/ContractsProvider";

export const useNFTContract = () => {
  const contract = useContext(NFTContext);
  const addresses = useContext(ContractsContext);
  let instance = contract.instance;

  if (!addresses) {
    throw new Error(
      "No addresses found. Make sure you are using the ContractsProvider"
    );
  }

  if (contract.instance) {
    instance = contract.instance.attach(addresses.nftAddress);
  }

  return instance;
};
