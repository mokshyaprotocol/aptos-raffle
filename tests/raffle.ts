//Test Code for aptos raffle contract
import { AptosClient,TokenClient, AptosAccount, FaucetClient, } from "aptos";

const NODE_URL = process.env.APTOS_NODE_URL || "https://fullnode.devnet.aptoslabs.com";
const FAUCET_URL = process.env.APTOS_FAUCET_URL || "https://faucet.devnet.aptoslabs.com";
export const timeDelay = async (s: number): Promise<unknown> => {
  const delay = new Promise((resolve) => setTimeout(resolve, s*1000));
  return delay;
};

const client = new AptosClient(NODE_URL);
const faucetClient = new FaucetClient(NODE_URL, FAUCET_URL);
//pid
const pid="0x16174b11a0360ae4a5a4149c5464c506a3ba06fb61ab8128d547011630670b21";
// Raffle Creator
const account1 = new AptosAccount();
// Raffle Player
const account2 = new AptosAccount();
//Token Info
const collection = "Mokshya Collection 11";
const tokenname = "Mokshya Token #11";
const description="Mokshya Token for test"
const uri = "https://github.com/mokshyaprotocol"
const tokenPropertyVersion = BigInt(0);

const token_data_id =  {creator: account1.address().hex(),
  collection: collection,
  name: tokenname,

}
const tokenId = {
  token_data_id,
  property_version: `${tokenPropertyVersion}`,
};
const tokenClient = new TokenClient(client); 

/**
 * Testing Raffle Contract
 */
 describe("Token Raffle", () => {
  it ("Create Collection", async () => {
    await faucetClient.fundAccount(account1.address(), 1000000000);//Airdropping
    const create_collection_payloads = {
      type: "entry_function_payload",
      function: "0x3::token::create_collection_script",
      type_arguments: [],
      arguments: [collection,description,uri,BigInt(100),[false, false, false]],
    };
    let txnRequest = await client.generateTransaction(account1.address(), create_collection_payloads);
    let bcsTxn = AptosClient.generateBCSTransaction(account1, txnRequest);
    await client.submitSignedBCSTransaction(bcsTxn);
  });
  it ("Create Token", async () => {
    const create_token_payloads = {
      type: "entry_function_payload",
      function: "0x3::token::create_token_script",
      type_arguments: [],
      arguments: [collection,tokenname,description,BigInt(5),BigInt(10),uri,account1.address(),
        BigInt(100),BigInt(0),[ false, false, false, false, false, false ],
        [ "attack", "num_of_use"],
        [[1,2],[1,2]],
        ["Bro","Ho"]
      ],
    };
    let txnRequest = await client.generateTransaction(account1.address(), create_token_payloads);
    let bcsTxn = AptosClient.generateBCSTransaction(account1, txnRequest);
    await client.submitSignedBCSTransaction(bcsTxn);
  });
  it ("Start Raffle", async () => {
    //Time and Amounts
    const now = Math.floor(Date.now() / 1000)
    const start_time = BigInt(now+10);
    const end_time = BigInt(now+20);
    const sartraffle_payloads = {
      type: "entry_function_payload",
      function: pid+"::raffle::start_raffle",
      type_arguments: ["0x1::aptos_coin::AptosCoin"],
      arguments: [account1.address(),collection,tokenname,tokenPropertyVersion,
        start_time,end_time,10,100
      ],
    };
    let txnRequest = await client.generateTransaction(account1.address(), sartraffle_payloads);
    let bcsTxn = AptosClient.generateBCSTransaction(account1, txnRequest);
    await client.submitSignedBCSTransaction(bcsTxn);
    await timeDelay(10);
  });
  it ("Play Raffle", async () => {
    await faucetClient.fundAccount(account2.address(), 1000000000);//Airdropping
    const playraffle_payloads = {
      type: "entry_function_payload",
      function: pid+"::raffle::play_raffle",
      type_arguments: ["0x1::aptos_coin::AptosCoin"],
      arguments: [collection,tokenname,9
      ],
    };
    let txnRequest = await client.generateTransaction(account2.address(), playraffle_payloads);
    let bcsTxn = AptosClient.generateBCSTransaction(account2, txnRequest);
    await client.submitSignedBCSTransaction(bcsTxn);
    await timeDelay(10);
  });
  it ("Draw Raffle", async () => {
    await faucetClient.fundAccount(account1.address(), 1000000000);//Airdropping
    const drawraffle_payloads = {
      type: "entry_function_payload",
      function: pid+"::raffle::declare_winner",
      type_arguments: ["0x1::aptos_coin::AptosCoin"],
      arguments: [collection,tokenname,
      ],
    };
    let txnRequest = await client.generateTransaction(account1.address(), drawraffle_payloads);
    let bcsTxn = AptosClient.generateBCSTransaction(account1, txnRequest);
    await client.submitSignedBCSTransaction(bcsTxn);
  });
  it ("Check Winner", async () => {
    await faucetClient.fundAccount(account2.address(), 1000000000);//Airdropping
    const playraffle_payloads = {
      type: "entry_function_payload",
      function: pid+"::raffle::check_claim_reward",
      type_arguments: [],
      arguments: [collection,tokenname
      ],
    };
    let txnRequest = await client.generateTransaction(account2.address(), playraffle_payloads);
    let bcsTxn = AptosClient.generateBCSTransaction(account2, txnRequest);
    await client.submitSignedBCSTransaction(bcsTxn);
  });
  });
