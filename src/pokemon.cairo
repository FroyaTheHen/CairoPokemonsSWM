use starknet::{ContractAddress};
use core::dict::Felt252Dict;


#[derive(Serde, Debug, Drop, Copy, PartialEq, starknet::Store)]
pub enum SpeciesType {
    # [default]
    Water,
    Fire,
    Grass
}


#[derive(Serde, Clone, Debug, Drop, PartialEq, starknet::Store)]
pub struct Pokemon {
    pub name: ByteArray,
    pub species_type: SpeciesType,
    pub likes_counter: u64,
    pub id: felt252,
}


// pub trait PokemonTrait<TContractState>  {
//     fn like(self: @Pokemon) -> ByteArray;
// }


#[starknet::interface]
pub trait IPokeStarknet<TContractState> {
    fn vote(ref self: TContractState, name: ByteArray);
    fn create_new_pokemon(ref self: TContractState, name: ByteArray, species_type: SpeciesType);
    fn get_pokemons_count(self: @TContractState) -> felt252;
    fn increase_poke_count(ref self: TContractState);
    fn get_pokemons(self: @TContractState) -> Array<Pokemon>;
    fn get_pokemon(self: @TContractState, name: ByteArray) -> Pokemon;

}

#[starknet::contract]
mod PokeStarknet {
    use core::starknet::storage::{StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map};
    use core::starknet::{ContractAddress, get_caller_address};
    use super::*;

    #[storage]
    struct Storage {
        balance: felt252,
        pokemon_count: felt252,
        pokemons: Map<felt252, Pokemon>,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, 
        // pokemon: Pokemon // plus times 3??
    ) {
        let pokemon1 = Pokemon {
            name: "first random pokemon",
            species_type: SpeciesType::Fire,
            likes_counter: 0,
            id: 1,
        };
        let pokemon2 = Pokemon {
            name: "second random pokemon",
            species_type: SpeciesType::Water,
            likes_counter: 0,
            id: 2,
        };
        let pokemon3 = Pokemon {
            name: "third random pokemon",
            species_type: SpeciesType::Grass,
            likes_counter: 0,
            id: 3,
        };
        self.pokemons.write(1, pokemon1);
        self.pokemons.write(2, pokemon2);
        self.pokemons.write(3, pokemon3);

        self.pokemon_count.write(3);
    }  


    #[abi(embed_v0)]
    impl PokeStarknetImpl of super::IPokeStarknet<ContractState> {
        fn create_new_pokemon(ref self: ContractState, name: ByteArray, species_type: SpeciesType
        ) {
            let new_pokemon = Pokemon {
                name: name,
                species_type: species_type,
                likes_counter: 0,
                id: 1,
            };
            self.pokemons.write(4, new_pokemon)
        }

        fn vote(ref self: ContractState, name: ByteArray) {
            // self.
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
            let poke_count = self.pokemon_count.read();
            let mut i = poke_count;

            let result = loop {
                let mut pokemon: Pokemon = self.pokemons.read(i);
                if name == pokemon.name {
                    break pokemon;
                }
                i -= 1;
            }; 
            result
    }

    }
}
