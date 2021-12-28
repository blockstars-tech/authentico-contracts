const Authentico = artifacts.require("Authentico");

const main = async () => {
  const authentico = await Authentico.new();
  console.log("authentico address is ->", authentico.address);
};

main()
  .then(() => {
    console.log("Success!");
    process.exit(0);
  })
  .catch((err) => {
    console.log("err is ->", err);
    process.exit(1);
  });
