// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.0;

// The Game contract controls all game logic
contract Game {

    // event NewPiece(uint pieceId, uint range, uint readyTime);

    struct Piece {
        address owner;
        uint color;
    }

    string public gameType;
    uint256 public size;
    uint256 public lastColor;
    uint256 public cooldownTime;

    // Map x to y to geo data
    mapping (uint => mapping (uint => uint)) _geo;
    // Map x to y to piece struct
    mapping (uint => mapping (uint => Piece)) _pieces;
    // Map x to y to color
    mapping (uint => mapping (uint => uint)) _colors;
    // Map player addresses to active/inactive
    mapping (address => bool) _players;
    // Map player address to cooldown timer
    mapping (address => uint) _cooldowns;

    constructor(string memory _gameType, uint256 _size, uint _cooldownTime) {
        gameType = _gameType;
        size = _size;
        uint x = 1;
        uint y = 0;

        _geo[x + 0][y + 3] = 1;
        _geo[x + 0][y + 4] = 1;

        _geo[x + 1][y + 4] = 1;
        _geo[x + 1][y + 5] = 1;
        _geo[x + 1][y + 6] = 1;
        _geo[x + 1][y + 7] = 1;

        _geo[x + 2][y + 3] = 1;
        _geo[x + 2][y + 4] = 1;
        _geo[x + 2][y + 5] = 1;
        _geo[x + 2][y + 6] = 1;
        _geo[x + 2][y + 7] = 1;

        _geo[x + 3][y + 2] = 1;
        _geo[x + 3][y + 3] = 1;
        _geo[x + 3][y + 4] = 1;
        _geo[x + 3][y + 5] = 1;
        _geo[x + 3][y + 6] = 1;
        _geo[x + 3][y + 7] = 1;
        _geo[x + 3][y + 8] = 1;
        _geo[x + 3][y + 9] = 1;
        
        _geo[x + 4][y + 3] = 1;
        _geo[x + 4][y + 4] = 1;
        _geo[x + 4][y + 6] = 1;
        _geo[x + 4][y + 7] = 1;
        _geo[x + 4][y + 8] = 1;
        _geo[x + 4][y + 9] = 1;
        _geo[x + 4][y + 10] = 1;

        _geo[x + 5][y + 7] = 1;
        _geo[x + 5][y + 8] = 1;

        _geo[x + 6][y + 2] = 1;
        _geo[x + 6][y + 4] = 1;
        _geo[x + 6][y + 5] = 1;
        _geo[x + 6][y + 8] = 1;
        _geo[x + 6][y + 9] = 1;
        _geo[x + 6][y + 10] = 1;

        _geo[x + 7][y + 2] = 1;
        _geo[x + 7][y + 3] = 1;
        _geo[x + 7][y + 4] = 1;
        _geo[x + 7][y + 5] = 1;
        _geo[x + 7][y + 6] = 1;
        _geo[x + 7][y + 9] = 1;

        _geo[x + 8][y + 3] = 1;
        _geo[x + 8][y + 4] = 1;
        _geo[x + 8][y + 5] = 1;
        _geo[x + 8][y + 9] = 1;
        _geo[x + 8][y + 10] = 1;

        _geo[x + 9][y + 4] = 1;

        _geo[x + 10][y + 7] = 1;
        _geo[x + 10][y + 8] = 1;

        _geo[x + 11][y + 8] = 1;

        cooldownTime = _cooldownTime;
    }

    function getGeoAt(uint _x, uint _y) public view returns (uint) {
        return _geo[_x][_y];
    }
    
    function getPieceAt(uint _x, uint _y) public view returns (Piece memory) {
        return _pieces[_x][_y];
    }

    function getColorAt(uint _x, uint _y) public view returns (uint) {
        return _colors[_x][_y];
    }

    function getPlayer(address _state) public view returns (bool) {
        return _players[_state];
    }

    function getCooldown(address _player) public view returns (uint) {
        return _cooldowns[_player];
    }

    function nextColor(uint _color) public pure returns (uint) {
        return (_color  % 4) + 1;
    }

    function spawnPiece (uint _x, uint _y) public {
        require(_x >= 0 && _x < size && _y >= 0 && _y < size, "Can't spawn outside of board");
        require(_players[msg.sender] == false, "Can't spawn more than one piece");
        require(_geo[_x][_y] != 1, "Can't spawn in water");
        require(_pieces[_x][_y].owner == address(0), "Can't spawn in occupied space");
        _pieces[_x][_y].owner = msg.sender;
        lastColor = nextColor(lastColor);
        _pieces[_x][_y].color = lastColor;
        _players[msg.sender] = true;
        _paint(_x, _y, _pieces[_x][_y].color);
    }

    function moveTo(uint _x, uint _y) public {
        require(_x >= 0 && _x < size && _y >= 0 && _y < size, "Can't move outside of board");
        require(_players[msg.sender] == true, "Must have a piece to move");
        // An ortogonal coordinate to the target coordinate must be the previous piece's location
        require(
            _pieces[_x][_y + 1].owner == msg.sender ||
            _pieces[_x + 1][_y].owner == msg.sender ||
            (_y == 0 || _pieces[_x][_y - 1].owner == msg.sender) ||
            (_x == 0 || _pieces[_x - 1][_y].owner == msg.sender)
        , "Must move to adjacent spaces");
        require(_geo[_x][_y] != 1, "Can't move to water space");
        require(_cooldowns[msg.sender] < block.timestamp, "Can't move in cooldown");

        uint x0;
        uint y0;

        // Calculate original piece location from ortogonal coordinates
        if (_pieces[_x][_y + 1].owner == msg.sender) {
            x0 = _x;
            y0 = _y + 1;
        }
        if (_pieces[_x + 1][_y].owner == msg.sender) {
            x0 = _x + 1;
            y0 = _y;
        }
        if (_y != 0 && _pieces[_x][_y - 1].owner == msg.sender) {
            x0 = _x;
            y0 = _y - 1;
        }
        if (_x != 0 && _pieces[_x - 1][_y].owner == msg.sender) {
            x0 = _x - 1;
            y0 = _y;
        }
        _players[_pieces[_x][_y].owner] = false;
        _pieces[_x][_y].owner = _pieces[x0][y0].owner;
        _pieces[_x][_y].color = _pieces[x0][y0].color;
        _paint(_x, _y, _pieces[_x][_y].color);
        _triggerCooldown(_pieces[_x][_y].owner, cooldownTime);
        _pieces[x0][y0].owner = address(0);
        _pieces[x0][y0].color = 0;
    }

    function _paint(uint _x, uint _y, uint _color) private {
        require(_x >= 0 && _x < size && _y >= 0 && _y < size, "Can't paint outside of board limits");
        require(getGeoAt(_x, _y) != 1, "Can't paint terrain tiles");
        _colors[_x][_y] = _color;
    }

    function _triggerCooldown(address _player, uint _cooldownTime) private {
        _cooldowns[_player] = uint32(block.timestamp + _cooldownTime);
    }
}