async function main() {
    // We get the contract to deploy

    const YieldManager = await ethers.getContractFactory("YieldManager");
    const yield = await YieldManager.deploy("");
    await yield.deployed();
    console.log("YieldManager deployed to:", yield.address);

}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
