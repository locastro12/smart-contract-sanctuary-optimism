// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../libraries/LibGeoWebParcel.sol";
import "../libraries/LibGeoWebParcelV2.sol";
import {IGeoWebParcelV1, IGeoWebParcelV2} from "../interfaces/IGeoWebParcel.sol";

/// @title Public access to parcel data
contract GeoWebParcelFacetV1 is IGeoWebParcelV1 {
    /**
     * @notice Get availability index for coordinates
     * @param x X coordinate
     * @param y Y coordinate
     */
    function availabilityIndex(uint256 x, uint256 y)
        external
        view
        returns (uint256)
    {
        LibGeoWebParcel.DiamondStorage storage ds = LibGeoWebParcel
            .diamondStorage();

        return ds.availabilityIndex[x][y];
    }

    /**
     * @notice Get a land parcel
     * @param id ID of land parcel
     */
    function getLandParcel(uint256 id)
        external
        view
        virtual
        returns (uint64 baseCoordinate, uint256[] memory path)
    {
        LibGeoWebParcel.DiamondStorage storage ds = LibGeoWebParcel
            .diamondStorage();

        LibGeoWebParcel.LandParcel storage p = ds.landParcels[id];
        return (p.baseCoordinate, p.path);
    }
}

/// @title Public access to parcel data
contract GeoWebParcelFacetV2 is GeoWebParcelFacetV1, IGeoWebParcelV2 {
    /**
     * @notice Get a V2 land parcel
     * @param id ID of land parcel
     */
    function getLandParcelV2(uint256 id)
        external
        view
        returns (
            uint64 swCoordinate,
            uint256 latDim,
            uint256 lngDim
        )
    {
        LibGeoWebParcelV2.DiamondStorage storage ds = LibGeoWebParcelV2
            .diamondStorage();

        LibGeoWebParcelV2.LandParcel storage p = ds.landParcels[id];
        return (p.swCoordinate, p.latDim, p.lngDim);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./LibGeoWebCoordinate.sol";

library LibGeoWebParcel {
    using LibGeoWebCoordinate for uint64;
    using LibGeoWebCoordinatePath for uint256;

    bytes32 private constant STORAGE_POSITION =
        keccak256("diamond.standard.diamond.storage.LibGeoWebParcel");

    /// @dev Structure of a land parcel
    struct LandParcel {
        uint64 baseCoordinate;
        uint256[] path;
    }

    /// @dev Enum for different actions
    enum Action {
        Build,
        Destroy,
        Check
    }

    /// @dev Maxmium uint256 stored as a constant to use for masking
    uint256 private constant MAX_INT = 2**256 - 1;

    /// @notice Emitted when a parcel is built
    event ParcelBuilt(uint256 indexed _id);

    /// @notice Emitted when a parcel is destroyed
    event ParcelDestroyed(uint256 indexed _id);

    /// @notice Emitted when a parcel is modified
    event ParcelModified(uint256 indexed _id);

    struct DiamondStorage {
        /// @notice Stores which coordinates are available
        mapping(uint256 => mapping(uint256 => uint256)) availabilityIndex;
        /// @notice Stores which coordinates belong to a parcel
        mapping(uint256 => LandParcel) landParcels;
        /// @dev The next ID to assign to a parcel
        uint256 nextId;
    }

    function diamondStorage()
        internal
        pure
        returns (DiamondStorage storage ds)
    {
        bytes32 position = STORAGE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            ds.slot := position
        }
    }

    /**
     * @notice Build a new parcel. All coordinates along the path must be available. All coordinates are marked unavailable after creation.
     * @param baseCoordinate Base coordinate of new parcel
     * @param path Path of new parcel
     */
    function build(uint64 baseCoordinate, uint256[] memory path) internal {
        require(
            path.length > 0,
            "LibGeoWebParcel: Path must have at least one component"
        );

        DiamondStorage storage ds = diamondStorage();

        // Mark everything as available
        _updateAvailabilityIndex(Action.Build, baseCoordinate, path);

        LandParcel storage p = ds.landParcels[ds.nextId];
        p.baseCoordinate = baseCoordinate;
        p.path = path;

        emit ParcelBuilt(ds.nextId);

        ds.nextId += 1;
    }

    /**
     * @notice Destroy an existing parcel. All coordinates along the path are marked as available.
     * @param id ID of land parcel
     */
    function destroy(uint256 id) internal {
        DiamondStorage storage ds = diamondStorage();

        LandParcel storage p = ds.landParcels[id];

        _updateAvailabilityIndex(Action.Destroy, p.baseCoordinate, p.path);

        delete ds.landParcels[id];

        emit ParcelDestroyed(id);
    }

    /**
     * @notice The next ID to assign to a parcel
     */
    function nextId() internal view returns (uint256) {
        DiamondStorage storage ds = diamondStorage();
        return ds.nextId;
    }

    /// @dev Update availability index by traversing a path and marking everything as available or unavailable
    function _updateAvailabilityIndex(
        Action action,
        uint64 baseCoordinate,
        uint256[] memory path
    ) private {
        DiamondStorage storage ds = diamondStorage();

        uint64 currentCoord = baseCoordinate;

        uint256 pI = 0;
        uint256 currentPath = path[pI];

        (uint256 iX, uint256 iY, uint256 i) = currentCoord.toWordIndex();
        uint256 word = ds.availabilityIndex[iX][iY];

        do {
            if (action == Action.Build) {
                // Check if coordinate is available
                require(
                    (word & (2**i) == 0),
                    "LibGeoWebParcel: Coordinate is not available"
                );

                // Mark coordinate as unavailable in memory
                word = word | (2**i);
            } else if (action == Action.Destroy) {
                // Mark coordinate as available in memory
                word = word & ((2**i) ^ MAX_INT);
            }

            // Get next direction
            bool hasNext;
            LibGeoWebCoordinate.Direction direction;
            (hasNext, direction, currentPath) = currentPath.nextDirection();

            if (!hasNext) {
                // Try next path
                pI += 1;
                if (pI >= path.length) {
                    break;
                }
                currentPath = path[pI];
                (hasNext, direction, currentPath) = currentPath.nextDirection();
            }

            // Traverse to next coordinate
            uint256 newIX;
            uint256 newIY;
            (currentCoord, newIX, newIY, i) = currentCoord.traverse(
                direction,
                iX,
                iY,
                i
            );

            // If new coordinate is in new word
            if (newIX != iX || newIY != iY) {
                // Update word in storage
                ds.availabilityIndex[iX][iY] = word;

                // Advance to next word
                word = ds.availabilityIndex[newIX][newIY];
            }

            iX = newIX;
            iY = newIY;
        } while (true);

        // Update last word in storage
        ds.availabilityIndex[iX][iY] = word;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./LibGeoWebParcel.sol";
import "./LibGeoWebCoordinate.sol";

uint256 constant MAX_PARCEL_DIM = 200;

library LibGeoWebParcelV2 {
    using LibGeoWebCoordinate for uint64;

    bytes32 private constant STORAGE_POSITION =
        keccak256("diamond.standard.diamond.storage.LibGeoWebParcelV2");

    /// @dev Structure of a land parcel
    struct LandParcel {
        uint64 swCoordinate;
        uint256 lngDim;
        uint256 latDim;
    }

    struct DiamondStorage {
        /// @notice Stores which coordinates belong to a parcel
        mapping(uint256 => LandParcel) landParcels;
    }

    function diamondStorage()
        internal
        pure
        returns (DiamondStorage storage ds)
    {
        bytes32 position = STORAGE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            ds.slot := position
        }
    }

    /**
     * @notice Build a new parcel. All coordinates along the path must be available. All coordinates are marked unavailable after creation.
     * @param parcel New parcel
     */
    function build(LandParcel memory parcel) internal {
        require(
            parcel.latDim <= MAX_PARCEL_DIM && parcel.latDim > 0,
            "LibGeoWebParcel: Latitude dimension out of bounds"
        );
        require(
            parcel.lngDim <= MAX_PARCEL_DIM && parcel.lngDim > 0,
            "LibGeoWebParcel: Longitude dimension out of bounds"
        );

        LibGeoWebParcel.DiamondStorage storage dsV1 = LibGeoWebParcel
            .diamondStorage();
        DiamondStorage storage dsV2 = diamondStorage();

        // Mark everything as available
        _updateAvailabilityIndex(parcel);

        dsV2.landParcels[dsV1.nextId] = parcel;

        emit LibGeoWebParcel.ParcelBuilt(dsV1.nextId);

        dsV1.nextId += 1;
    }

    /// @dev Update availability index by traversing a path and marking everything as available or unavailable
    function _updateAvailabilityIndex(LandParcel memory parcel) private {
        LibGeoWebParcel.DiamondStorage storage dsV1 = LibGeoWebParcel
            .diamondStorage();

        uint64 currentCoord = parcel.swCoordinate;

        (uint256 iX, uint256 iY, uint256 i) = currentCoord.toWordIndex();
        uint256 word = dsV1.availabilityIndex[iX][iY];

        LibGeoWebCoordinate.Direction lngDir = LibGeoWebCoordinate
            .Direction
            .East;

        for (uint256 lat = 0; lat < parcel.latDim; lat++) {
            for (uint256 lng = 0; lng < parcel.lngDim; lng++) {
                // Check if coordinate is available
                require(
                    (word & (2**i) == 0),
                    "LibGeoWebParcel: Coordinate is not available"
                );

                // Mark coordinate as unavailable in memory
                word = word | (2**i);

                // Get next direction
                LibGeoWebCoordinate.Direction direction;
                if (lng < parcel.lngDim - 1) {
                    direction = lngDir;
                } else if (lat < parcel.latDim - 1) {
                    direction = LibGeoWebCoordinate.Direction.North;
                    if (lngDir == LibGeoWebCoordinate.Direction.East) {
                        lngDir = LibGeoWebCoordinate.Direction.West;
                    } else {
                        lngDir = LibGeoWebCoordinate.Direction.East;
                    }
                } else {
                    break;
                }

                // Traverse to next coordinate
                uint256 newIX;
                uint256 newIY;
                (currentCoord, newIX, newIY, i) = currentCoord.traverse(
                    direction,
                    iX,
                    iY,
                    i
                );

                // If new coordinate is in new word
                if (newIX != iX || newIY != iY) {
                    // Update word in storage
                    dsV1.availabilityIndex[iX][iY] = word;

                    // Advance to next word
                    word = dsV1.availabilityIndex[newIX][newIY];
                }

                iX = newIX;
                iY = newIY;
            }
        }

        // Update last word in storage
        dsV1.availabilityIndex[iX][iY] = word;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

/// @title Latest version of IGeoWebParcel
interface IGeoWebParcel {
    /**
     * @notice Get availability index for coordinates
     * @param x X coordinate
     * @param y Y coordinate
     */
    function availabilityIndex(uint256 x, uint256 y)
        external
        view
        returns (uint256);

    /**
     * @notice Get a land parcel
     * @param id ID of land parcel
     */
    function getLandParcel(uint256 id)
        external
        view
        returns (uint64 baseCoordinate, uint256[] memory path);

    /**
     * @notice Get a V2 land parcel
     * @param id ID of land parcel
     */
    function getLandParcelV2(uint256 id)
        external
        view
        returns (
            uint64 swCoordinate,
            uint256 latDim,
            uint256 lngDim
        );
}

/// @title IGeoWebParcelV1 external functions
interface IGeoWebParcelV1 {
    /**
     * @notice Get availability index for coordinates
     * @param x X coordinate
     * @param y Y coordinate
     */
    function availabilityIndex(uint256 x, uint256 y)
        external
        view
        returns (uint256);

    /**
     * @notice Get a land parcel
     * @param id ID of land parcel
     */
    function getLandParcel(uint256 id)
        external
        view
        returns (uint64 baseCoordinate, uint256[] memory path);
}

/// @title IGeoWebParcelV2 defines new external functions
interface IGeoWebParcelV2 is IGeoWebParcelV1 {
    /**
     * @notice Get a V2 land parcel
     * @param id ID of land parcel
     */
    function getLandParcelV2(uint256 id)
        external
        view
        returns (
            uint64 swCoordinate,
            uint256 latDim,
            uint256 lngDim
        );
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

/// @title LibGeoWebCoordinate is an unsigned 64-bit integer that contains x and y coordinates in the upper and lower 32 bits, respectively
library LibGeoWebCoordinate {
    // Fixed grid size is 2^23 longitude by 2^22 latitude
    uint64 public constant MAX_X = ((2**23) - 1);
    uint64 public constant MAX_Y = ((2**22) - 1);

    /// @dev Enum for different directions
    enum Direction {
        North,
        South,
        East,
        West
    }

    /// @notice Traverse a single direction
    /// @param origin The origin coordinate to start from
    /// @param direction The direction to take
    /// @return destination The destination coordinate
    function traverse(
        uint64 origin,
        Direction direction,
        uint256 iX,
        uint256 iY,
        uint256 i
    )
        internal
        pure
        returns (
            uint64,
            uint256,
            uint256,
            uint256
        )
    {
        uint64 originX = _getX(origin);
        uint64 originY = _getY(origin);

        if (direction == Direction.North) {
            originY += 1;
            require(originY <= MAX_Y, "Direction went too far north!");

            if (originY % 16 == 0) {
                iY += 1;
                i -= 240;
            } else {
                i += 16;
            }
        } else if (direction == Direction.South) {
            require(originY > 0, "Direction went too far south!");
            originY -= 1;

            if (originY % 16 == 15) {
                iY -= 1;
                i += 240;
            } else {
                i -= 16;
            }
        } else if (direction == Direction.East) {
            if (originX >= MAX_X) {
                // Wrap to west
                originX = 0;
                iX = 0;
                i -= 15;
            } else {
                originX += 1;
                if (originX % 16 == 0) {
                    iX += 1;
                    i -= 15;
                } else {
                    i += 1;
                }
            }
        } else if (direction == Direction.West) {
            if (originX == 0) {
                // Wrap to east
                originX = MAX_X;
                iX = MAX_X / 16;
                i += 15;
            } else {
                originX -= 1;
                if (originX % 16 == 15) {
                    iX -= 1;
                    i += 15;
                } else {
                    i -= 1;
                }
            }
        }

        uint64 destination = (originY | (originX << 32));

        return (destination, iX, iY, i);
    }

    /// @notice Get the X coordinate
    function _getX(uint64 coord) internal pure returns (uint64 coordX) {
        coordX = (coord >> 32); // Take first 32 bits
        require(coordX <= MAX_X, "X coordinate is out of bounds");
    }

    /// @notice Get the Y coordinate
    function _getY(uint64 coord) internal pure returns (uint64 coordY) {
        coordY = (coord & ((2**32) - 1)); // Take last 32 bits
        require(coordY <= MAX_Y, "Y coordinate is out of bounds");
    }

    /// @notice Convert coordinate to word index
    function toWordIndex(uint64 coord)
        internal
        pure
        returns (
            uint256 iX,
            uint256 iY,
            uint256 i
        )
    {
        uint256 coordX = uint256(_getX(coord));
        uint256 coordY = uint256(_getY(coord));

        iX = coordX / 16;
        iY = coordY / 16;

        uint256 lX = coordX % 16;
        uint256 lY = coordY % 16;

        i = lY * 16 + lX;
    }
}

/// @notice LibGeoWebCoordinatePath stores a path of directions in a uint256. The most significant 8 bits encodes the length of the path
library LibGeoWebCoordinatePath {
    uint256 private constant INNER_PATH_MASK = (2**(256 - 8)) - 1;
    uint256 private constant PATH_SEGMENT_MASK = (2**2) - 1;

    /// @notice Get next direction from path
    /// @param path The path to get the direction from
    /// @return hasNext If the path has a next direction
    /// @return direction The next direction taken from path
    /// @return nextPath The next path with the direction popped from it
    function nextDirection(uint256 path)
        internal
        pure
        returns (
            bool hasNext,
            LibGeoWebCoordinate.Direction direction,
            uint256 nextPath
        )
    {
        uint256 length = (path >> (256 - 8)); // Take most significant 8 bits
        hasNext = (length > 0);
        if (!hasNext) {
            return (hasNext, LibGeoWebCoordinate.Direction.North, 0);
        }
        uint256 _path = (path & INNER_PATH_MASK);

        direction = LibGeoWebCoordinate.Direction(_path & PATH_SEGMENT_MASK); // Take least significant 2 bits of path
        nextPath = (_path >> 2) | ((length - 1) << (256 - 8)); // Trim direction from path
    }
}