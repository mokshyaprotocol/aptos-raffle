
import { HexString,AptosClient, Provider,Network,TxnBuilderTypes, BCS } from "aptos";



export class RaffleClient
{
  client: AptosClient;
  pid: string;
  provider:Provider;

  constructor(nodeUrl: string, pid:string,network:Network) {
    this.client = new AptosClient(nodeUrl);
    // Initialize the module owner account here
    this.pid = pid
    this.provider= new Provider(network)
  }
  /**
   * Inititate raffle for the token
   * @param raffleCreator raffle creator
   * @param creatorAddress Collection Creator Address
   * @param collectionName Collection name
   * @param tokenName Token name
   * @param propertyVersion token property version
   * @param startTime starting of raffle
   * @param endTime end of raffle
   * @param totalTickets total available tickets
   * @param ticketPrize prize of each ticket
   * @returns Promise<TxnBuilderTypes.RawTransaction>
   */
  // :!:>startRaffle
  async startRaffle(
    raffleCreator: HexString,
    creatorAddress: HexString,
    collectionName: string,
    tokenName: string,
    propertyVersion: BCS.AnyNumber,
    startTime:  BCS.AnyNumber,
    endTime: BCS.AnyNumber,
    totalTickets: BCS.AnyNumber,
    ticketPrize:  BCS.AnyNumber
  ): Promise<TxnBuilderTypes.RawTransaction> {
    return await this.provider.generateTransaction(raffleCreator, {
      function: `${this.pid}::raffle::start_raffle`,
      type_arguments: ["0x1::aptos_coin::AptosCoin"],
      arguments: [raffleCreator,creatorAddress, collectionName,tokenName,propertyVersion,
        startTime,endTime,totalTickets,ticketPrize],
    });
  }
  /**
   * Play Raffle
   * @param  playerAddress raffle player
   * @param collectionName Collection name
   * @param tokenName Token name
   * @param numTickets Number of Tickets
   * @returns Promise<TxnBuilderTypes.RawTransaction>
   */
  // :!:>playRaffle
  async play_raffle(
    playerAddress:HexString,
    collectionName: string,
    tokenName: string,
    numTickets: BCS.AnyNumber,
    ): Promise<TxnBuilderTypes.RawTransaction> {
      return await this.provider.generateTransaction(playerAddress, {
        function: `${this.pid}::raffle::play_raffle`,
        type_arguments: ["0x1::aptos_coin::AptosCoin"],
        arguments: [collectionName, tokenName,numTickets],
      });
  }
    /**
   * Declare Raffle Winner
   * @param raffleCreator raffle creator
   * @param collectionName Collection name
   * @param tokenName Token name
   * @returns Promise<TxnBuilderTypes.RawTransaction>
   */
  // :!:>declare_winner
  async declare_winner(
    raffleCreator:HexString,
    collectionName: string,
    tokenName: string,
    ): Promise<TxnBuilderTypes.RawTransaction> {
      return await this.provider.generateTransaction(raffleCreator, {
        function: `${this.pid}::raffle::declare_winner`,
        type_arguments: ["0x1::aptos_coin::AptosCoin"],
        arguments: [collectionName, tokenName],
      });
  }
  /**
   * Check Raffle Winner
   * @param playerAddress player Address
   * @param collectionName Collection name
   * @param tokenName Token name
   * @param numTickets Number of Tickets
   * @returns Promise<TxnBuilderTypes.RawTransaction>
   */
  // :!:>check_claim_reward
  async check_claim_reward(
    playerAddress:HexString,
    collectionName: string,
    tokenName: string,
    ): Promise<TxnBuilderTypes.RawTransaction> {
      return await this.provider.generateTransaction(playerAddress, {
        function: `${this.pid}::raffle::check_claim_reward`,
        type_arguments: ["0x1::aptos_coin::AptosCoin"],
        arguments: [collectionName, tokenName,],
      });
  }
  }

