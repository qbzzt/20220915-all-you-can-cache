// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import "./Cache.sol";



contract WORM is Cache {

    struct Entry {  
        uint value;
        address writtenBy;
        uint writtenAtBlock;
    }   // struct Entry

    mapping(uint => Entry) public entries;

    // An entry has been written. There is no need for the event to specify by whom or at what block,
    // because the event is connected to the transaction that initiated it.
    event EntryWritten(uint indexed key, uint indexed value);

    function writeEntry(uint _key, uint _value) public {
        require(entries[_key].writtenBy == address(0), "entry already written");

        entries[_key].writtenBy = tx.origin;
        entries[_key].value = _value;
        entries[_key].writtenAtBlock = block.number;

        emit EntryWritten(_key, _value);
    }   // writeEntry


    function writeEntryCached() external {
        uint[] memory params = _readParams(2);
        writeEntry(params[0], params[1]);
    }    // writeEntryCached

    // Make it easier to call us
    // Function signature for writeEntryCached(), courtesy of
    // https://www.4byte.directory/signatures/?bytes4_signature=0xe4e4f2d3
    bytes4 constant public WRITE_ENTRY_CACHED = 0xe4e4f2d3;


    function readEntry(uint key) public view 
        returns (uint _value, address _writtenBy, uint _writtenAtBlock)
    { 
        Entry memory entry = entries[key];
        require(entry.writtenBy != address(0), "no entry for this key");
        return (entry.value, entry.writtenBy, entry.writtenAtBlock);
    }


}  // WORM