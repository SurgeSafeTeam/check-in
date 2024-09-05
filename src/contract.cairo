use starknet::ContractAddress;

#[starknet::interface]
pub trait ICheckIn<TContractState> {
    fn get_name(self: @TContractState) -> felt252;
    fn get_token_uri(self: @TContractState, token_id: u256) -> ByteArray;
    fn get_all_addresses(self: @TContractState) -> Array<ContractAddress>;
    fn check_in(ref self: TContractState);
    // fn distribute_nft(
    //     ref self: TContractState, 
    //     base_uri_part_1: felt252, 
    //     base_uri_part_2: felt252, 
    //     base_uri_part_3: felt252,
    //     base_uri_part_3_len: usize,  
    //     symbol: felt252,
    //     symbol_len: usize,
    // );
}

#[starknet::contract]
pub mod CheckIn {
    use openzeppelin_token::erc721::interface::ERC721ABI;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait, MutableVecTrait
    };
    use checkin::convert::{convert1, convert2, convert3};

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // ERC721 Mixin
    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        name: felt252,
        participants: Vec<ContractAddress>,
        start_date: u64,
        end_date: u64,
        nft_issue: bool,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: felt252,
        start_date: u64,
        end_date: u64,
        nft_issue: bool
    ) {
        self.name.write(name);
        self.start_date.write(start_date);
        self.end_date.write(end_date);
        self.nft_issue.write(nft_issue);
    }

    #[abi(embed_v0)]
    impl CheckInImpl of super::ICheckIn<ContractState> {
        fn get_name(self: @ContractState) -> felt252 {
            self.name.read()
        }
        fn get_token_uri(self: @ContractState, token_id: u256) -> ByteArray {
            self.erc721.tokenURI(token_id)
        }

        fn check_in(ref self: ContractState){
            self.participants.append().write(get_caller_address());
        }

        fn get_all_addresses(self: @ContractState) -> Array<ContractAddress> {
            let mut addresses = array![];
            let mut i = 0;
            while (i < self.participants.len()){
                addresses.append(self.participants.at(i).read());
                i += 1;
            };
            addresses
        }

        // fn distribute_nft(
        //     ref self: ContractState, 
        //     base_uri_part_1: felt252, 
        //     base_uri_part_2: felt252,
        //     base_uri_part_3: felt252,
        //     base_uri_part_3_len: usize,
        //     symbol: felt252,
        //     symbol_len: usize,
        // ){
        //     assert(self.nft_issue.read() == true, 'NFT_ISSUE_N/A'); 

        //     let sbl = convert1(symbol, symbol_len);
        //     let base_uri = convert3(base_uri_part_1, base_uri_part_2, base_uri_part_3, base_uri_part_3_len);
        //     self.erc721.initializer(self.name.read(), convert1(symbol, symbol_len), base_uri);
        //     let participants = self.participants.read();
        //     //self.erc721.mint(recipient, token_id);
        // }
    }
}

