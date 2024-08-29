import { deployContract } from "./utils";
import { DeploymentType } from "zksync-ethers/build/types";

export default async function () {
  const contractArtifactName = "WETH9";
  const wethSalt = "0x0000000000000000000000000000000000000000000000000000000000000001";

  await deployContract(
    contractArtifactName,
    "create2" as DeploymentType,
    [], // constructorArguments (empty array if there are no constructor arguments)
    {}, // options (empty object if no options are needed)
    {
      customData: {
      salt: wethSalt
    }}
  );
}
