use starknet::{ContractAddress};


#[derive(Serde, Debug, Drop, Copy, PartialEq, starknet::Store)]
pub enum SpeciesType {
    #[default]
    Water,
    Fire,
    Grass
}


#[derive(Serde, Clone, Debug, Drop, PartialEq, starknet::Store)]
pub struct Pokemon {
    pub name: ByteArray, 
    pub species_type: SpeciesType,
    pub likes_counter: u64,
    pub id: felt252,  // id maps to index in storage pokemons attr
    pub owner: ContractAddress,
}


#[generate_trait]
pub impl PokemonImpl of PokemonTrait {
    fn like(ref self: Pokemon) {
        self.likes_counter += 1;
    }
    
}


#[starknet::interface]
pub trait IPokeStarknet<TContractState> {
    fn vote(ref self: TContractState, name: ByteArray);
    fn create_new_pokemon(ref self: TContractState, name: ByteArray, species_type: SpeciesType);
    fn get_pokemons_count(self: @TContractState) -> felt252;
    fn increase_poke_count(ref self: TContractState);
    fn get_pokemons(self: @TContractState) -> Array<Pokemon>;
    fn get_pokemon(self: @TContractState, name: ByteArray) -> Pokemon; // panics if pokemon doesn't exist
    fn get_pokemon_with_index(self: @TContractState, name: ByteArray) -> Option<(felt252, Pokemon)>;
    fn user_likes_pokemon(ref self: TContractState, name: ByteArray) -> bool;
}

#[starknet::contract]
mod PokeStarknet {
use ERC20Component::InternalTrait;
use super::IPokeStarknet;
use core::starknet::storage::{StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map};
    use core::starknet::{ContractAddress, get_caller_address};
    use super::{Pokemon, SpeciesType, PokemonTrait};
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);


    #[storage]
    struct Storage {
        pokemon_count: felt252,
        pokemons: Map<felt252, Pokemon>,
        likes_map: Map<ContractAddress, Map<felt252, bool>>, // user id <pokemon id, ~/liked 
        #[substorage(v0)]
        erc20: ERC20Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, 
    ) {
        let owner: ContractAddress = get_caller_address();
        let pokemon1 = Pokemon {
            name: "first random pokemon",
            species_type: SpeciesType::Fire,
            likes_counter: 0,
            id: 0,
            owner: owner,
        };
        let pokemon2 = Pokemon {
            name: "second random pokemon",
            species_type: SpeciesType::Water,
            likes_counter: 0,
            id: 1,
            owner: owner,
        };
        let pokemon3 = Pokemon {
            name: "third random pokemon",
            species_type: SpeciesType::Grass,
            likes_counter: 0,
            id: 2,
            owner: owner,
        };
        self.pokemons.write(0, pokemon1);
        self.pokemons.write(1, pokemon2);
        self.pokemons.write(2, pokemon3);

        self.pokemon_count.write(3);

        let name = "MyToken";
        let symbol = "MTK";

        self.erc20.initializer(name, symbol);
    }  


    #[abi(embed_v0)]
    impl PokeStarknetImpl of super::IPokeStarknet<ContractState> {
        fn create_new_pokemon(ref self: ContractState, name: ByteArray, species_type: SpeciesType
        ) {
            let owner: ContractAddress = get_caller_address();
            let new_pokemon = Pokemon { 
                name: name,
                species_type: species_type,
                likes_counter: 0,
                id: self.pokemon_count.read().into(),
                owner: owner,
            };

            // TODO: there must be a nicer way to write the uniqe name validation
            let pokemon_clone = new_pokemon.clone(); // How to preserving lifetime nicer?? 
            let res = self.get_pokemon_with_index(pokemon_clone.name);
            if res.is_some(){
                panic!("Pokemon already exists");
            }
            //

            self.pokemons.write(3, new_pokemon);
            self.increase_poke_count();
            
            let caller = get_caller_address();
            self.erc20.burn(caller, 1);
        }

        fn vote(ref self: ContractState, name: ByteArray) {
            let (mut index, mut pokemon) =  self.get_pokemon_with_index(name).unwrap();
            pokemon.like();            

            self.pokemons.write(index, pokemon);
            let caller = get_caller_address();
            self.likes_map.entry(caller).entry(index).write(true);
            
            self.erc20.mint(caller, 1);
        }

        fn get_pokemons_count(self: @ContractState) -> felt252 {
            self.pokemon_count.read()
        }

        fn increase_poke_count(ref self: ContractState) {
            let count: felt252 = 1;
            self.pokemon_count.write(self.pokemon_count.read() + count);
        }

        fn get_pokemons(self: @ContractState) -> Array<Pokemon> {
            let mut pokemons: Array<Pokemon> = ArrayTrait::new();
            let mut i = 0;
            let poke_count = self.pokemon_count.read();

            while i != poke_count {
                pokemons.append(self.pokemons.entry(i).read());
                i += 1;
            };
            pokemons
        }

        fn get_pokemon(self: @ContractState, name: ByteArray) -> Pokemon {
            let (_index, pokemon) =  self.get_pokemon_with_index(name).unwrap();
            pokemon
        }

        fn get_pokemon_with_index(self: @ContractState, name: ByteArray) -> Option<(felt252, Pokemon)> {
            let poke_count = self.pokemon_count.read();
            let mut i = poke_count;

            loop {
                let mut pokemon = self.pokemons.read(i);
                if name == pokemon.name {
                    break Option::Some((i, pokemon));
                }
                i -= 1;
                if i == -1 {
                    break Option::None;
                }
            }

        }

        fn user_likes_pokemon(ref self: ContractState, name: ByteArray) -> bool {
            let caller: ContractAddress = get_caller_address();
            let (index, _pokemon) =  self.get_pokemon_with_index(name).unwrap();
            self.likes_map.entry(caller).entry(index).read()
        }

    }
}
