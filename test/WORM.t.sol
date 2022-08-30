// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";


// Need to run `forge test -vv` for the console.
import "forge-std/console.sol";
import "src/WORM.sol";

contract WORMTest is Test {
    WORM worm;

    function setUp() public {
        worm = new WORM();        
    }

    function testWReadWrite() public {
        worm.writeEntry(0xDEAD, 0x60A7);

        vm.expectRevert(bytes("entry already written"));
        worm.writeEntry(0xDEAD, 0xBEEF);

        uint val;
        uint blockNum;
        address writer;
        (val, writer, blockNum) = worm.readEntry(uint(0xDEAD));
        assertEq(val, 0x60A7);

        vm.expectRevert(bytes("no entry for this key"));
        (val, writer, blockNum) = worm.readEntry(uint(0xBEEF));       
    }    // testReadWrite    

    function testReadWriteCached() public {
        uint cacheGoat = worm.cacheWrite(0x60A7);
        uint cacheBeef = worm.cacheWrite(0xBEEF);
        uint cacheDead = worm.cacheWrite(0xDEAD);
        uint cacheSage = worm.cacheWrite(0x5A6E);

        assertEq(cacheGoat, 1);
        assertEq(cacheBeef, 2);
        assertEq(cacheDead, 3);
        assertEq(cacheSage, 4); 

        assertEq(uint32(worm.WRITE_ENTRY_CACHED()), 0xe4e4f2d3);

        bool _success;
        bytes memory _callInput;

        // Write entries
        _callInput = bytes.concat(
            worm.WRITE_ENTRY_CACHED(),
            bytes1(uint8(cacheGoat)),    // Key
            bytes1(uint8(cacheSage))     // Value
        );
        (_success,) = address(worm).call(_callInput);
        assertEq(_success, true);

        _callInput = bytes.concat(
            worm.WRITE_ENTRY_CACHED(),
            bytes1(uint8(cacheDead)), bytes1(uint8(cacheBeef)) 
        );
        (_success,) = address(worm).call(_callInput);
        assertEq(_success, true);        

        // Fail to overwrite
        _callInput = bytes.concat(
            worm.WRITE_ENTRY_CACHED(),
            bytes1(uint8(cacheDead)), bytes1(uint8(cacheGoat)) 
        );
        (_success,) = address(worm).call(_callInput);
        assertEq(_success, false);  

        uint val;

        (val,,) = worm.readEntry(0xDEAD);
        assertEq(val, 0xBEEF);


        (val,,) = worm.readEntry(0x60A7);
        assertEq(val, 0x5A6E);

        vm.expectRevert(bytes("no entry for this key"));
        (val,,) = worm.readEntry(0xBEEF);

        vm.expectRevert(bytes("no entry for this key"));        
        (val,,) = worm.readEntry(0x5A6E);    
    }   // testReadWriteCached

    event EntryWritten(uint indexed key, uint indexed value);

    // This tests every part of the system together
    // The parameters make Foundry turn on the fuzzer
    function testFull(uint a, uint b, uint c) public {
        bool _success;
        bytes memory _callInput;
        uint retVal;


        _callInput = bytes.concat(
            worm.WRITE_ENTRY_CACHED(), worm.encodeVal(a), worm.encodeVal(b));
        vm.expectEmit(true, true, false, false);
        emit EntryWritten(a, b);
        (_success,) = address(worm).call(_callInput);
        assertEq(_success, true);
        assertEq(_callInput.length, 4+33*2);
        (retVal,,) = worm.readEntry(a);
        assertEq(retVal, b); 

        // Only create the reverse if a!=b, otherwise we'll get a failure
        if (a != b) {                        
            _callInput = bytes.concat(
                worm.WRITE_ENTRY_CACHED(), worm.encodeVal(b), worm.encodeVal(a));

            vm.expectEmit(true, true, false, false);
            emit EntryWritten(b, a);
            (_success,) = address(worm).call(_callInput);
            assertEq(_success, true);
            assertEq(_callInput.length, 4+1*2);
            (retVal,,) = worm.readEntry(b);
            assertEq(retVal, a); 
        }

        // If c is not already in the cache
        if (a != c && b != c) {
            _callInput = bytes.concat(
                worm.WRITE_ENTRY_CACHED(), worm.encodeVal(c), worm.encodeVal(a));
            vm.expectEmit(true, true, false, false);
            emit EntryWritten(c, a);                
            (_success,) = address(worm).call(_callInput);
            assertEq(_success, true);
            assertEq(_callInput.length, 4+33+1);
            (retVal,,) = worm.readEntry(c);
            assertEq(retVal, a); 
        }

        // Also try a failure
        _callInput = bytes.concat(
            worm.WRITE_ENTRY_CACHED(), worm.encodeVal(a), worm.encodeVal(c));
        (_success,) = address(worm).call(_callInput);
        assertEq(_success, false);
        assertEq(_callInput.length, 4+1*2);
    }  // testFull

}  // WORMTest