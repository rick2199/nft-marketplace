import { createContext, FC } from "react";
import { Symfoni, SymfoniProps } from "./__generated__/SymfoniContext";

export interface ContractAddresses {
  nftAddress: string;
  nftMarketAdress: string;
}
interface Props extends SymfoniProps {
  addresses: ContractAddresses;
}

export const ContractsContext = createContext<ContractAddresses | null>(null);

export const ContractsProvider: FC<Props> = (props) => {
  const { children, addresses, ...rest } = props;

  return (
    <ContractsContext.Provider value={addresses}>
      <Symfoni {...rest}>{children}</Symfoni>
    </ContractsContext.Provider>
  );
};
