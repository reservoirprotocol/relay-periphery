import { deployContract } from "./utils";
import { DeploymentType } from "zksync-ethers/build/types";

export default async function () {}

const deployWETH9 = async () => {
  const salt = "0x0000000000000000000000000000000000000000000000000000000000000001";

  await deployContract(
    "WETH9",
    "create2" as DeploymentType,
    [], // constructorArguments (empty array if there are no constructor arguments)
    {}, // options (empty object if no options are needed)
    {
      customData: {
      salt: salt
    }}
  );
}

const deployPermit2 = async () => {
  const salt = "0x0000000000000000000000000000000000000000000000000000000000000001";

  await deployContract(
    "Permit2",
    "create2" as DeploymentType,
    [], // constructorArguments (empty array if there are no constructor arguments)
    {}, // options (empty object if no options are needed)
    {
      customData: {
      salt: salt
    }}
  );
}
