use starknet::SyscallResultTrait;
use starknet::{Store, SyscallResult};
use starknet::storage_access::StorageBaseAddress;
use starknet::ContractAddress;

// ANCHOR: StorageAccessImpl
impl StoreContractAddressArray of Store<Array<ContractAddress>> {
    fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<Array<ContractAddress>> {
        StoreContractAddressArray::read_at_offset(address_domain, base, 0)
    }

    fn write(
        address_domain: u32, base: StorageBaseAddress, value: Array<ContractAddress>
    ) -> SyscallResult<()> {
        StoreContractAddressArray::write_at_offset(address_domain, base, 0, value)
    }

    fn read_at_offset(
        address_domain: u32, base: StorageBaseAddress, mut offset: u8
    ) -> SyscallResult<Array<ContractAddress>> {
        let mut arr: Array<ContractAddress> = array![];

        // Read the stored array's length. If the length is greater than 255, the read will fail.
        let len: u8 = Store::<u8>::read_at_offset(address_domain, base, offset)
            .expect('Storage Span too large');
        offset += 1;

        // Sequentially read all stored elements and append them to the array.
        let exit = len + offset;
        loop {
            if offset >= exit {
                break;
            }

            let value = Store::<ContractAddress>::read_at_offset(address_domain, base, offset).unwrap();
            arr.append(value);
            offset += Store::<ContractAddress>::size();
        };

        // Return the array.
        Result::Ok(arr)
    }

    fn write_at_offset(
        address_domain: u32, base: StorageBaseAddress, mut offset: u8, mut value: Array<ContractAddress>
    ) -> SyscallResult<()> {
        // Store the length of the array in the first storage slot.
        let len: u8 = value.len().try_into().expect('Storage - Span too large');
        Store::<u8>::write_at_offset(address_domain, base, offset, len).unwrap();
        offset += 1;

        // Store the array elements sequentially
        while let Option::Some(element) = value
            .pop_front() {
                Store::<ContractAddress>::write_at_offset(address_domain, base, offset, element).unwrap();
                offset += Store::<ContractAddress>::size();
            };

        Result::Ok(())
    }

    fn size() -> u8 {
        255 * Store::<ContractAddress>::size()
    }
}

#[starknet::interface]
pub trait ICheckIn<TContractState> {
    fn get_name(self: @TContractState) -> felt252;
    fn get_token_uri(self: @TContractState, token_id: u256) -> ByteArray;
    fn print_participants(self: @TContractState) -> usize;
    fn check_in(ref self: TContractState);
    fn distribute_nft(
        ref self: TContractState, 
        base_uri_part_1: felt252, 
        base_uri_part_2: felt252, 
        base_uri_part_3: felt252,
        base_uri_part_3_len: usize,  
        symbol: felt252,
        symbol_len: usize,
    );
}

#[starknet::contract]
pub mod CheckIn {
    use openzeppelin_token::erc721::interface::ERC721ABI;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use starknet::{ContractAddress, get_caller_address};
    use super::StoreContractAddressArray;
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
        participants: Array<ContractAddress>,
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
        let mut array: Array<ContractAddress> = array![];
        self.participants.write(array);
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
            let mut participants = self.participants.read();
            participants.append(get_caller_address());
            self.participants.write(participants)
        }

        fn print_participants(self: @ContractState) -> usize{
            let participants = self.participants.read();
            let size = participants.len();
            if(size > 0){
                println!("participants address as follows:");
            };
            let mut i = 0;
            while (i < size){
                let participant = *participants.at(i);
                let output: felt252 = participant.into();
                println!("{output}");
                i += 1;
            };
            size
        }
        fn distribute_nft(
            ref self: ContractState, 
            base_uri_part_1: felt252, 
            base_uri_part_2: felt252,
            base_uri_part_3: felt252,
            base_uri_part_3_len: usize,
            symbol: felt252,
            symbol_len: usize,
        ){
            assert(self.nft_issue.read() == true, 'NFT_ISSUE_N/A'); 

            let sbl = convert1(symbol, symbol_len);
            let base_uri = convert3(base_uri_part_1, base_uri_part_2, base_uri_part_3, base_uri_part_3_len);
            self.erc721.initializer(self.name.read(), convert1(symbol, symbol_len), base_uri);
            let participants = self.participants.read();
            //self.erc721.mint(recipient, token_id);
        }
    }
}

