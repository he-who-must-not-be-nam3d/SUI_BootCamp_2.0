module calculator::Bootcamp {
    /// Import necessary Sui and standard library modules
    use sui::object::{Self, UID};    // For creating unique identifiers
    use sui::transfer;               // For transferring objects
    use sui::tx_context::{Self, TxContext};  // For transaction context
    use std::option::{Option, Self}; // For handling optional values
    use std::vector;                 // For working with dynamic arrays

    // Maximum allowed calculation value to prevent overflow
    const MAX_CALCULATION_LIMIT: u64 = 100000;
    // Custom error code for overflow scenarios
    const ERROR_OVERFLOW: u64 = 1001;

    /// Struct to store the entire calculation history
    /// Has `store` ability to be stored in objects
    /// Has `drop` ability to be easily discarded
    public struct CalculationHistory has store, drop {
        /// Vector of calculation records
        operations: vector<CalculationRecord>
    }

    /// Struct representing a single calculation record
    /// Stores operation type, inputs, and result
    public struct CalculationRecord has store, drop {
        /// Operation type (add, subtract, etc.) as bytes
        operation: vector<u8>,
        /// Input values converted to bytes
        inputs: vector<u8>,
        /// Calculation result
        results: u64
    }

    /// Main Calculator object that can be transferred between accounts
    /// Has `key` ability to be used as a transferable object
    public struct Calculator has key {
        /// Unique identifier for the object
        id: UID,
        /// Calculation history for this calculator
        history: CalculationHistory
    }

    /// Converts a u64 integer to a byte vector
    /// Handles conversion for storage and serialization
    fun u64_to_bytes(value: u64): vector<u8> {
        // Initialize an empty byte vector
        let mut bytes = vector::empty<u8>();
        let mut current = value;
        
        // Special case for zero
        if (current == 0) {
            vector::push_back(&mut bytes, 0);
            return bytes
        };
        
        // Convert each digit to a byte
        while (current > 0) {
            // Get least significant byte
            vector::push_back(&mut bytes, (current % 256 as u8));
            // Move to next digit
            current = current / 256;
        };
        
        // Reverse to get correct byte order
        vector::reverse(&mut bytes);
        
        bytes
    }

    /// Addition function with overflow protection
    public fun add(a: u64, b: u64): u64 {
        // Ensure inputs are within allowed limits
        assert!(a <= MAX_CALCULATION_LIMIT && b <= MAX_CALCULATION_LIMIT, ERROR_OVERFLOW);
        a + b
    }

    /// Subtraction function with overflow protection
    public fun subtract(a: u64, b: u64): u64 {
        // Ensure inputs are within allowed limits
        assert!(a <= MAX_CALCULATION_LIMIT && b <= MAX_CALCULATION_LIMIT, ERROR_OVERFLOW);
        //Ensure a is greater than b before trying to substract
        assert!(a >= b, ERROR_OVERFLOW);
        a - b
    }

    /// Multiplication function that returns an Option
    /// Returns None if inputs exceed limit
    public fun multiply(a: u64, b: u64): Option<u64> {
        // Check if inputs are within limits
        if (a > MAX_CALCULATION_LIMIT || b > MAX_CALCULATION_LIMIT) {
            option::none()
        } else {
            option::some(a * b)
        }
    }

    /// Division function that returns an Option
    /// Returns None for division by zero
    public fun divide(a: u64, b: u64): Option<u64> {
        // Prevent division by zero
        if (b == 0) {
            option::none()
        } else {
            option::some(a / b)
        }
    }

    /// Input validation function
    /// Checks if both inputs are within calculation limits
    fun validate_input(a: u64, b: u64): bool {
        a <= MAX_CALCULATION_LIMIT && b <= MAX_CALCULATION_LIMIT
    }

    /// Advanced calculation function that supports multiple operations
    /// Uses byte strings to determine operation type
    public fun advance_calculation(
        a: u64,
        b: u64,
        operation: vector<u8>
    ): Option<u64> {
        // Validate input first
        assert!(validate_input(a, b), ERROR_OVERFLOW);
        
        // Determine operation based on byte string
        if (operation == b"add") {
            option::some(add(a, b))
        } else if (operation == b"subtract") {
            option::some(subtract(a, b))
        } else if (operation == b"multiply") {
            multiply(a, b)
        } else if (operation == b"divide") {
            divide(a, b)
        } else {
            // Return None for unknown operations
            option::none()
        }
    }

    /// Creates a new calculation record
    /// Converts inputs to bytes for storage
    public fun create_calculation_record(
        operation: vector<u8>,
        a: u64,
        b: u64,
        result: u64
    ): CalculationRecord {
        // Convert inputs to byte vector
        let mut inputs = u64_to_bytes(a);
        vector::append(&mut inputs, u64_to_bytes(b));
        
        // Create and return record
        CalculationRecord {
            operation,
            inputs,
            results: result
        }
    }

    /// Adds a calculation record to the history
    public fun record_calculation(
        history: &mut CalculationHistory,
        record: CalculationRecord
    ) {
        vector::push_back(&mut history.operations, record);
    }
    /// Approximate log2(n)
    public fun log2_approx(n: u64): u64 {
        let mut count = 0;
        let mut value = n;
        while (value > 1) {
            value = value / 2;
            count = count + 1;
        };
        count
    }
    /// Approximate log10(n) using repeated division
    public fun log10_approx(n: u64): u64 {
        let mut count = 0;
        let mut value = n;
        while (value >= 10) {
            value = value / 10;
            count = count + 1;
        };
        count
    }

    /// Entry function to perform a calculation and create a Calculator object
    /// This is the main public interface for performing calculations
    public entry fun perform_calculation(
        a: u64,
        b: u64,
        operation: vector<u8>,
        ctx: &mut TxContext
    ) {
        // Create a new Calculator object with empty history
        let mut calculator = Calculator {
            id: object::new(ctx),
            history: CalculationHistory { operations: vector::empty() }
        };

        // Perform the calculation
        let result_option = advance_calculation(a, b, operation);
        
        // If calculation is successful, record it
        if (option::is_some(&result_option)) {
            let result = *option::borrow(&result_option);
            let record = create_calculation_record(
                operation,
                a,
                b,
                result
            );
            record_calculation(&mut calculator.history, record);
        };

        // Transfer the Calculator object to the transaction sender
        transfer::transfer(calculator, tx_context::sender(ctx));
    }

    /// Retrieves the calculation history from a Calculator object
    public fun get_calculation_history(calculator: &Calculator): &vector<CalculationRecord> {
        &calculator.history.operations
    }
}