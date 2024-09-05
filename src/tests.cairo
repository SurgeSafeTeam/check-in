
use snforge_std::{ declare, ContractClassTrait, start_cheat_caller_address };
use starknet::{ ContractAddress, contract_address_const};

use checkin::contract::ICheckInDispatcher;
use checkin::contract::ICheckInDispatcherTrait;
use openzeppelin_testing::{declare_and_deploy};


// pub fn OWNER() -> ContractAddress {
//     contract_address_const::<'OWNER'>()
// }


fn setup_dispatcher() -> ICheckInDispatcher {
    let mut calldata = ArrayTrait::new();
    // name: ByteArray,
    // start_date: u256,
    // end_date: u256,
    // nft_issue: bool
    calldata.append('TEST_NAME'); 
    let start: u64 = 0;
    calldata.append(start.into()); 
    let end: u64 = 100;
    calldata.append(end.into()); 
    let nft_issue: u8 = 0;
    calldata.append(nft_issue.into()); 
    
    let address = declare_and_deploy("CheckIn", calldata); //mod name

    start_cheat_caller_address(address, contract_address_const::<'OWNER'>());
    ICheckInDispatcher { contract_address: address}
}


#[test]
fn test_dispatch() {
    let dispatcher = setup_dispatcher();
    let name = dispatcher.get_name();
    println!("event name: {name}");
}