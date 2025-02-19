// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.7 <0.9.0;

import '@mean-finance/dca-v2-core/contracts/interfaces/IDCAHub.sol';
import 'base64-sol/base64.sol';
import '../interfaces/IDCAHubPositionDescriptor.sol';
import '../libraries/DescriptorUtils.sol';
import '../libraries/IntervalUtils.sol';

/// @title Describes NFT token positions
/// @notice Produces a string containing the data URI for a JSON metadata string
contract DCAHubPositionDescriptor is IDCAHubPositionDescriptor {
  using Strings for uint256;
  using Strings for uint32;

  struct PositionParams {
    string tokenId;
    string fromToken;
    string toToken;
    uint8 fromDecimals;
    uint8 toDecimals;
    string fromSymbol;
    string toSymbol;
    string swapInterval;
    uint32 swapsExecuted;
    uint32 swapsLeft;
    uint256 toWithdraw;
    uint256 remaining;
    uint160 rate;
  }

  /// @inheritdoc IDCAHubPositionDescriptor
  function tokenURI(address _hub, uint256 _tokenId) external view returns (string memory) {
    IDCAHub.UserPosition memory _userPosition = IDCAHub(_hub).userPosition(_tokenId);

    return
      _constructTokenURI(
        PositionParams({
          tokenId: _tokenId.toString(),
          fromToken: DescriptorUtils.addressToString(address(_userPosition.from)),
          toToken: DescriptorUtils.addressToString(address(_userPosition.to)),
          fromDecimals: _userPosition.from.decimals(),
          toDecimals: _userPosition.to.decimals(),
          fromSymbol: _userPosition.from.symbol(),
          toSymbol: _userPosition.to.symbol(),
          swapInterval: IntervalUtils.intervalToDescription(_userPosition.swapInterval),
          swapsExecuted: _userPosition.swapsExecuted,
          toWithdraw: _userPosition.swapped,
          swapsLeft: _userPosition.swapsLeft,
          remaining: _userPosition.remaining,
          rate: _userPosition.rate
        })
      );
  }

  function _constructTokenURI(PositionParams memory _params) internal pure returns (string memory) {
    string memory _name = _generateName(_params);
    string memory _description = _generateDescription(_params);
    string memory _image = Base64.encode(bytes(_generateSVG(_params)));
    return
      string(
        abi.encodePacked(
          'data:application/json;base64,',
          Base64.encode(
            bytes(
              abi.encodePacked('{"name":"', _name, '", "description":"', _description, '", "image": "data:image/svg+xml;base64,', _image, '"}')
            )
          )
        )
      );
  }

  function _generateDescription(PositionParams memory _params) private pure returns (string memory) {
    string memory _part1 = string(
      abi.encodePacked(
        'This NFT represents a DCA position in Mean Finance, where ',
        _params.fromSymbol,
        ' will be swapped for ',
        _params.toSymbol,
        '. The owner of this NFT can modify or redeem the position.\\n\\n',
        _params.fromSymbol
      )
    );
    string memory _part2 = string(
      abi.encodePacked(
        ' Address: ',
        _params.fromToken,
        '\\n',
        _params.toSymbol,
        ' Address: ',
        _params.toToken,
        '\\nSwap interval: ',
        _params.swapInterval,
        '\\nToken ID: ',
        _params.tokenId,
        '\\n\\n',
        unicode'⚠️ DISCLAIMER: Due diligence is imperative when assessing this NFT. Make sure token addresses match the expected tokens, as token symbols may be imitated.'
      )
    );
    return string(abi.encodePacked(_part1, _part2));
  }

  function _generateName(PositionParams memory _params) private pure returns (string memory) {
    return string(abi.encodePacked('Mean Finance DCA - ', _params.swapInterval, ' - ', _params.fromSymbol, unicode' ➔ ', _params.toSymbol));
  }

  function _generateSVG(PositionParams memory _params) internal pure returns (string memory) {
    uint32 _percentage = (_params.swapsExecuted + _params.swapsLeft) > 0
      ? (_params.swapsExecuted * 100) / (_params.swapsExecuted + _params.swapsLeft)
      : 100;
    return
      string(
        abi.encodePacked(
          '<svg version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 580.71 1118.71" >',
          _generateStyleDefs(_percentage),
          _generateSVGDefs(),
          _generateSVGBackground(),
          _generateSVGCardMantle(_params),
          _generateSVGPositionData(_params),
          _generateSVGBorderText(_params),
          _generateSVGLinesAndMainLogo(_percentage),
          _generageSVGProgressArea(_params),
          '</svg>'
        )
      );
  }

  function _generateStyleDefs(uint32 _percentage) private pure returns (string memory) {
    return
      string(
        abi.encodePacked(
          '<style type="text/css">.st0{fill:url(#SVGID_1)}.st1{fill:none;stroke:#fff;stroke-miterlimit:10}.st2{opacity:.5}.st3{fill:none;stroke:#b5baba;stroke-miterlimit:10}.st36{fill:#fff}.st37{fill:#48a7de}.st38{font-family:"Verdana"}.st39{font-size:60px}.st40{letter-spacing:-4}.st44{font-size:25px}.st46{fill:#c6c6c6}.st47{font-size:18px}.st48{font-size:19.7266px}.st49{font-family:"Verdana";font-weight:bold}.st50{font-size:38px}.st52{stroke:#848484;mix-blend-mode:multiply}.st55{opacity:.2;fill:#fff}.st57{fill:#48a7de;stroke:#fff;stroke-width:2.8347;stroke-miterlimit:10}.st58{font-size:18px}.cls-79{stroke:#d1dbe0;transform:rotate(-90deg);transform-origin:290.35px 488.04px;animation:dash 2s linear alternate forwards}@keyframes dash{from{stroke-dashoffset:750.84}to{stroke-dashoffset:',
          (((100 - _percentage) * 75084) / 10000).toString(),
          ';}}</style>'
        )
      );
  }

  function _generateSVGDefs() private pure returns (string memory) {
    return
      '<defs><path id="SVGID_0" class="st2" d="M580.71 1042.17c0 42.09-34.44 76.54-76.54 76.54H76.54c-42.09 0-76.54-34.44-76.54-76.54V76.54C0 34.44 34.44 0 76.54 0h427.64c42.09 0 76.54 34.44 76.54 76.54v965.63z"/><path id="text-path-a" d="M81.54 1095.995a57.405 57.405 0 0 1-57.405-57.405V81.54A57.405 57.405 0 0 1 81.54 24.135h417.64a57.405 57.405 0 0 1 57.405 57.405v955.64a57.405 57.405 0 0 1-57.405 57.405z"/><path id="text-path-executed" d="M290.35 348.77a139.5 139.5 0 1 1 0 279 139.5 139.5 0 1 1 0-279"/><path id="text-path-left" d="M290.35 348.77a-139.5-139.5 0 1 0 0 279 139.5 139.5 0 1 0 0-279"/><radialGradient id="SVGID_3" cx="334.831" cy="592.878" r="428.274" fx="535.494" fy="782.485" gradientUnits="userSpaceOnUse"><stop offset="0"/><stop offset=".11" stop-color="#0d1f29"/><stop offset=".28" stop-color="#1f4860"/><stop offset=".45" stop-color="#2e6a8d"/><stop offset=".61" stop-color="#3985b0"/><stop offset=".76" stop-color="#4198c9"/><stop offset=".89" stop-color="#46a3d9"/><stop offset="1" stop-color="#48a7de"/>&gt;</radialGradient><linearGradient id="SVGID_1" gradientUnits="userSpaceOnUse" x1="290.353" y1="0" x2="290.353" y2="1118.706"><stop offset="0" stop-color="#48a7de"/><stop offset=".105" stop-color="#3e81a6"/><stop offset=".292" stop-color="#2e4e5d"/><stop offset=".47" stop-color="#1f2c30"/><stop offset=".635" stop-color="#121612"/><stop offset=".783" stop-color="#060600"/><stop offset=".91" stop-color="#010100"/><stop offset="1"/></linearGradient><clipPath id="SVGID_2"><use xlink:href="#SVGID_0" overflow="visible"/></clipPath></defs>';
  }

  function _generateSVGBackground() private pure returns (string memory) {
    return
      '<path d="M580.71 1042.17c0 42.09-34.44 76.54-76.54 76.54H76.54c-42.09 0-76.54-34.44-76.54-76.54V76.54C0 34.44 34.44 0 76.54 0h427.64c42.09 0 76.54 34.44 76.54 76.54v965.63z" fill="url(#SVGID_1)"/><path d="M76.54 1081.86c-21.88 0-39.68-17.8-39.68-39.68V76.54c0-21.88 17.8-39.69 39.68-39.69h427.64c21.88 0 39.68 17.8 39.68 39.69v965.64c0 21.88-17.8 39.68-39.68 39.68H76.54z" fill="none" stroke="#fff" stroke-miterlimit="10"/><g id="XMLID_29_" clip-path="url(#SVGID_2)" opacity=".5"><path id="XMLID_00000106106944977730228320000011315049117735843764_" class="st3" d="M-456.81 863.18S-230.72 1042 20.73 930.95s273.19-602.02 470.65-689.23 307.97 123.01 756.32-75.01" stroke-width=".14"/><path class="st3" d="M-458.59 859.15s220.19 166.13 470.94 55.39 280.67-577.29 480.99-665.76 302.72 97.74 747.09-98.53" stroke-width=".172"/><path class="st3" d="M-460.37 855.13s214.29 153.44 464.34 43.01 288.14-552.56 491.33-642.3 297.46 72.46 737.86-122.05" stroke-width=".204"/><path class="st3" d="M-462.15 851.1s208.38 140.76 457.74 30.62S291.21 353.91 497.27 262.9s292.2 47.19 728.63-145.56" stroke-width=".235"/><path class="st3" d="M-463.92 847.08s202.48 128.07 451.15 18.24 303.09-503.08 512.01-595.35 286.95 21.91 719.4-169.08" stroke-width=".267"/><path class="st3" d="M-465.7 843.05s196.58 115.38 444.55 5.86S289.41 370.57 501.2 277.03s281.69-3.36 710.16-192.6" stroke-width=".299"/><path class="st3" d="M-467.48 839.02s190.67 102.69 437.95-6.52 318.04-453.6 532.69-548.4 276.43-28.64 700.93-216.12" stroke-width=".33"/><path class="st3" d="M-469.26 835s184.77 90 431.35-18.9S287.6 387.23 505.12 291.16s271.18-53.91 691.7-239.64" stroke-width=".362"/><path class="st3" d="M-471.03 830.97s178.87 77.32 424.75-31.28S286.7 395.56 507.09 298.23s265.92-79.19 682.47-263.16" stroke-width=".394"/><path class="st3" d="M-472.81 826.95s172.97 64.63 418.16-43.66 340.45-379.4 563.7-478 260.66-104.46 673.24-286.68" stroke-width=".425"/><path class="st3" d="M-474.59 822.92s167.06 51.94 411.56-56.04S284.9 412.22 511.02 312.36s255.41-129.74 664.01-310.2" stroke-width=".457"/><path class="st3" d="M-476.37 818.9s161.16 39.25 404.96-68.42S284 420.55 512.98 319.42 763.13 164.41 1167.76-14.3" stroke-width=".489"/><path class="st3" d="M-478.15 814.87s155.26 26.57 398.36-80.8 362.88-305.18 594.73-407.58 244.9-180.29 645.55-357.24" stroke-width=".52"/><path class="st3" d="M-479.92 810.85s149.35 13.88 391.77-93.19S282.2 437.21 516.92 333.55s239.64-205.56 636.31-380.76" stroke-width=".552"/><path class="st3" d="M-481.7 806.82s143.45 1.19 385.17-105.57 377.82-255.71 615.41-360.64 234.38-230.84 627.08-404.27" stroke-width=".584"/><path class="st3" d="M-483.48 802.8s137.55-11.5 378.57-117.95 385.3-230.97 625.75-337.17S749.96 91.57 1138.69-80.11" stroke-width=".616"/><path class="st3" d="M-485.26 798.77s131.64-24.19 371.97-130.33C127.04 562.3 279.49 462.21 522.8 354.74S746.67 73.36 1131.42-96.57" stroke-width=".647"/><path class="st3" d="M-487.04 794.74s125.74-36.87 365.37-142.71 400.24-181.5 646.43-290.23 218.61-306.66 599.39-474.83" stroke-width=".679"/><path class="st3" d="M-488.81 790.72s119.84-49.56 358.78-155.09 407.72-156.76 656.76-266.76 213.35-331.93 590.16-498.35" stroke-width=".711"/><path class="st3" d="M-490.59 786.69s113.93-62.25 352.18-167.47C99.83 514 276.78 487.2 528.69 375.94s208.1-357.21 580.92-521.87" stroke-width=".742"/><path class="st3" d="M-492.37 782.67s108.03-74.94 345.58-179.85S275.88 495.53 530.66 383 733.5.52 1102.35-162.39" stroke-width=".774"/><path class="st3" d="M-494.15 778.64s102.13-87.62 338.98-192.23 430.14-82.55 687.78-196.34S730.2-17.69 1095.08-178.84" stroke-width=".806"/><path class="st3" d="M-495.92 774.62s96.23-100.31 332.39-204.61 437.61-57.81 698.12-172.87S726.91-35.9 1087.82-195.3" stroke-width=".837"/><path class="st3" d="M-497.7 770.59s90.32-113 325.79-217 445.08-33.08 708.46-149.4 187.07-458.31 544-615.95" stroke-width=".869"/><path class="st3" d="M-499.48 766.57s84.42-125.69 319.19-229.38 452.56-8.34 718.8-125.93 181.81-483.58 534.77-639.47" stroke-width=".901"/><path class="st3" d="M-501.26 762.54s78.52-138.38 312.59-241.76 460.03 16.4 729.14-102.46 176.56-508.86 525.54-662.99" stroke-width=".932"/><path class="st3" d="M-503.04 758.52s72.61-151.06 306-254.14 467.5 41.13 739.48-78.99 171.3-534.13 516.3-686.51" stroke-width=".964"/><path class="st3" d="M-504.81 754.49s66.71-163.75 299.4-266.52 474.98 65.87 749.82-55.52 166.04-559.41 507.07-710.02" stroke-width=".996"/><path class="st3" d="M-506.59 750.47s60.81-176.44 292.8-278.9 482.45 90.61 760.16-32.05 160.79-584.68 497.84-733.54" stroke-width="1.028"/><path class="st3" d="M-508.37 746.44s54.9-189.13 286.2-291.28 489.92 115.34 770.5-8.57 155.53-609.95 488.61-757.06" stroke-width="1.059"/><path class="st3" d="M-510.15 742.41s49-201.82 279.6-303.66c230.6-101.85 497.4 140.08 780.84 14.9s150.27-635.23 479.38-780.58" stroke-width="1.091"/><path class="st3" d="M-511.92 738.39s43.1-214.5 273.01-316.04c229.9-101.55 504.86 164.81 791.17 38.36s145.02-660.5 470.15-804.1" stroke-width="1.123"/></g><path class="st36" d="M506.55 691.2h-7.09v-1.62h.9c-.73-.41-1.11-1.3-1.11-2.1 0-.93.42-1.75 1.25-2.13-.93-.55-1.25-1.38-1.25-2.3 0-1.28.82-2.5 2.69-2.5h4.6v1.63h-4.32c-.83 0-1.46.42-1.46 1.37 0 .89.7 1.47 1.57 1.47h4.21v1.66h-4.32c-.82 0-1.46.41-1.46 1.37 0 .9.67 1.47 1.57 1.47h4.21v1.68zM504.53 672.8c1.24.38 2.24 1.5 2.24 3.2 0 1.92-1.4 3.63-3.8 3.63-2.24 0-3.73-1.66-3.73-3.45 0-2.18 1.44-3.47 3.68-3.47.28 0 .51.03.54.04v5.18c1.08-.04 1.85-.89 1.85-1.94 0-1.02-.54-1.54-1.24-1.78l.46-1.41zm-2.3 1.62c-.83.03-1.57.58-1.57 1.75 0 1.06.82 1.67 1.57 1.73v-3.48zM502.49 669.98l-.28-1.82c-.06-.41-.26-.52-.51-.52-.6 0-1.08.41-1.08 1.34 0 .89.57 1.38 1.28 1.46l-.35 1.54c-1.22-.13-2.32-1.24-2.32-2.99 0-2.18 1.24-3.01 2.65-3.01h3.52c.64 0 1.06-.07 1.14-.09v1.57c-.04.01-.33.07-.9.07.54.34 1.12 1.03 1.12 2.18 0 1.49-1.02 2.4-2.14 2.4-1.26.01-1.95-.92-2.13-2.13zm1.12-2.35h-.32l.28 1.85c.09.52.38.95.96.95.48 0 .92-.36.92-1.03 0-.95-.46-1.77-1.84-1.77zM506.55 662.83v1.69h-7.09v-1.65h.95c-.82-.47-1.15-1.31-1.15-2.1 0-1.73 1.25-2.56 2.81-2.56h4.48v1.69h-4.19c-.87 0-1.57.39-1.57 1.46 0 .96.74 1.47 1.67 1.47h4.09zM496.08 652.99h1.44c-.03.1-.07.29-.07.61 0 .44.2 1.05 1.08 1.05h.93v-4.72h7.09v1.66h-5.62v3.06h5.62v1.7h-5.62v1.24h-1.47v-1.24h-.98c-1.59 0-2.55-1.02-2.55-2.48.01-.42.1-.77.15-.88zm-.23-2.23c0-.61.5-1.11 1.11-1.11.6 0 1.09.5 1.09 1.11 0 .61-.5 1.09-1.09 1.09-.61 0-1.11-.48-1.11-1.09zM506.55 646.63v1.69h-7.09v-1.65h.95c-.82-.47-1.15-1.31-1.15-2.1 0-1.73 1.25-2.56 2.81-2.56h4.48v1.69h-4.19c-.87 0-1.57.39-1.57 1.46 0 .96.74 1.47 1.67 1.47h4.09zM502.49 638.84l-.28-1.82c-.06-.41-.26-.52-.51-.52-.6 0-1.08.41-1.08 1.34 0 .89.57 1.38 1.28 1.46l-.35 1.54c-1.22-.13-2.32-1.24-2.32-2.99 0-2.18 1.24-3.01 2.65-3.01h3.52c.64 0 1.06-.07 1.14-.09v1.57c-.04.01-.33.07-.9.07.54.33 1.12 1.03 1.12 2.18 0 1.49-1.02 2.4-2.14 2.4-1.26.01-1.95-.92-2.13-2.13zm1.12-2.35h-.32l.28 1.85c.09.52.38.95.96.95.48 0 .92-.36.92-1.03 0-.95-.46-1.77-1.84-1.77zM506.55 631.69v1.69h-7.09v-1.65h.95c-.82-.47-1.15-1.31-1.15-2.1 0-1.73 1.25-2.56 2.81-2.56h4.48v1.69h-4.19c-.87 0-1.57.39-1.57 1.46 0 .96.74 1.47 1.67 1.47h4.09zM503 624.47c1.43 0 2.23-.92 2.23-1.98 0-1.11-.77-1.62-1.31-1.78l.54-1.49c1.11.33 2.32 1.4 2.32 3.26 0 2.08-1.62 3.67-3.77 3.67-2.18 0-3.76-1.59-3.76-3.63 0-1.91 1.19-2.96 2.33-3.25l.55 1.51c-.63.16-1.32.64-1.32 1.72-.01 1.05.76 1.97 2.19 1.97zM504.53 612.11c1.24.38 2.24 1.5 2.24 3.2 0 1.92-1.4 3.63-3.8 3.63-2.24 0-3.73-1.66-3.73-3.45 0-2.18 1.44-3.47 3.68-3.47.28 0 .51.03.54.04v5.18c1.08-.04 1.85-.89 1.85-1.94 0-1.02-.54-1.54-1.24-1.78l.46-1.41zm-2.3 1.61c-.83.03-1.57.58-1.57 1.75 0 1.06.82 1.67 1.57 1.73v-3.48zM501.02 610.91c0 .02-.01.03-.03.03h-1.57c-.01 0-.02.01-.02.02v.36c0 .02-.01.03-.03.03h-.07c-.02 0-.03-.01-.03-.03v-.92c0-.02.01-.03.03-.03h.07c.02 0 .03.01.03.03v.36c0 .01.01.02.02.02H501c.02 0 .03.01.03.03v.1zM499.32 610.11c-.02 0-.03-.01-.03-.03v-.1c0-.02.01-.03.03-.04l1.16-.41v-.01l-1.16-.41c-.02-.01-.03-.02-.03-.04v-.1c0-.02.01-.03.03-.03H501c.02 0 .03.01.03.03v.09c0 .02-.01.03-.03.03h-1.33v.01l1.02.36c.02.01.03.02.03.03v.06c0 .02-.01.03-.03.03l-1.02.36v.01H501c.02 0 .03.01.03.03v.09c0 .02-.01.03-.03.03h-1.68z"/><path d="M504.7 695.31c-.02.58-2.31 1.27-3.55 1.65-2.5.75-4.86 1.47-4.86 3.42 0 1.75 1.9 2.49 3.85 3.11.22.07.66.21 1.91.58.16.05.31.09.47.13 1.1.31 2.06.59 2.06 1.27 0 .66-1.04 1-2.1 1.29-.44.12-2.06.6-2.25.66-1.99.63-3.93 1.38-3.93 3.14 0 1.96 2.36 2.67 4.87 3.42 1.23.37 3.53 1.06 3.55 1.63l-.02.66h1.85l.01-.61c0-1.99-2.36-2.7-4.86-3.45-.32-.1-.66-.18-.99-.27-1.24-.31-2.42-.61-2.42-1.38 0-.73 1.3-1.08 2.46-1.39.06-.01 1.74-.51 2.12-.63 1.79-.58 3.7-1.34 3.7-3.07 0-1.74-1.89-2.49-3.83-3.11-.34-.11-2.06-.62-2.21-.66-1.18-.32-2.24-.66-2.24-1.33 0-.77 1.17-1.07 2.42-1.38.33-.08.67-.17.99-.27 2.5-.75 4.86-1.47 4.86-3.46l-.01-.61h-1.85v.66z" fill="#48a7de"/>';
  }

  function _generateSVGBorderText(PositionParams memory _params) private pure returns (string memory) {
    string memory _fromText = string(abi.encodePacked(_params.fromToken, ' - ', _params.fromSymbol));
    string memory _toText = string(abi.encodePacked(_params.toToken, ' - ', _params.toSymbol));

    return
      string(
        abi.encodePacked(
          _generateTextWithPath('-100', _fromText),
          _generateTextWithPath('0', _fromText),
          _generateTextWithPath('50', _toText),
          _generateTextWithPath('-50', _toText)
        )
      );
  }

  function _generateTextWithPath(string memory _offset, string memory _text) private pure returns (string memory) {
    return
      string(
        abi.encodePacked(
          '<text text-rendering="optimizeSpeed"><textPath startOffset="',
          _offset,
          '%" xlink:href="#text-path-a" class="st46 st38 st47">',
          _text,
          '<animate additive="sum" attributeName="startOffset" from="0%" to="100%" dur="60s" repeatCount="indefinite" /></textPath></text>'
        )
      );
  }

  function _generateSVGCardMantle(PositionParams memory _params) private pure returns (string memory) {
    return
      string(
        abi.encodePacked(
          '<text><tspan x="68.3549" y="146.2414" class="st36 st38 st39 st40">',
          _params.fromSymbol,
          unicode'<tspan style="font-size: 40px;" dy="-5"> ➔ </tspan><tspan y="146.2414">',
          _params.toSymbol,
          '</tspan></tspan></text><text x="68.3549" y="225.9683" class="st36 st49 st50">',
          _params.swapInterval,
          '</text>'
        )
      );
  }

  function _generageSVGProgressArea(PositionParams memory _params) private pure returns (string memory) {
    return
      string(
        abi.encodePacked(
          '<text text-rendering="optimizeSpeed"><textPath xlink:href="#text-path-executed"><tspan class="st38 st58" fill="#d1dbe0" style="text-shadow:#214c64 0px 0px 5px">Executed*: ',
          _params.swapsExecuted.toString(),
          _params.swapsExecuted != 1 ? ' swaps' : ' swap',
          '</tspan></textPath></text><text text-rendering="optimizeSpeed"><textPath xlink:href="#text-path-left" startOffset="30%" ><tspan class="st38 st58" alignment-baseline="hanging" fill="#153041" stroke="#000" stroke-width="0.5">Left: ',
          _params.swapsLeft.toString(),
          _params.swapsLeft != 1 ? ' swaps' : ' swap',
          '</tspan></textPath></text>'
        )
      );
  }

  function _generateSVGPositionData(PositionParams memory _params) private pure returns (string memory) {
    string memory _toWithdraw = _amountToReadable(_params.toWithdraw, _params.toDecimals, _params.toSymbol);
    string memory _swapped = _amountToReadable(_params.rate * _params.swapsExecuted, _params.fromDecimals, _params.fromSymbol);
    string memory _remaining = _amountToReadable(_params.remaining, _params.fromDecimals, _params.fromSymbol);
    string memory _rate = _amountToReadable(_params.rate, _params.fromDecimals, _params.fromSymbol);
    return
      string(
        abi.encodePacked(
          '<text transform="matrix(1 0 0 1 68.3549 775.8853)"><tspan x="0" y="0" class="st36 st38 st44">Id: ',
          _params.tokenId,
          '</tspan><tspan x="0" y="52.37" class="st36 st38 st44">To Withdraw: ',
          _toWithdraw,
          '</tspan><tspan x="0" y="104.73" class="st36 st38 st44">Swapped*: ',
          _swapped,
          '</tspan><tspan x="0" y="157.1" class="st36 st38 st44">Remaining: ',
          _remaining,
          '</tspan><tspan x="0" y="209.47" class="st36 st38 st44">Rate: ',
          _rate,
          '</tspan></text><text><tspan x="68.3554" y="1050.5089" class="st36 st38 st48">* since start or last edit / withdraw</tspan></text>'
        )
      );
  }

  function _generateSVGLinesAndMainLogo(uint32 _percentage) private pure returns (string memory) {
    return
      string(
        abi.encodePacked(
          '<path class="st1" d="M68.35 175.29h440.12M68.35 249.38h440.12M68.35 737.58h440.12M68.35 792.11h440.12M68.35 844.47h440.12M68.35 896.82h440.12M68.35 949.17h440.12M68.35 1001.53h440.12"/><circle cx="290.35" cy="488.04" r="164.57" fill="url(#SVGID_3)"/><circle transform="rotate(-45.001 290.349 488.046)" class="st1" cx="290.35" cy="488.04" r="177.22"/><circle class="st52" cx="290.35" cy="488.04" r="119.5" stroke-width="21" fill="none" stroke-linecap="round"/><path class="st55" d="M359.92 508.63c-3.97-.13-8.71-15.84-11.26-24.3-5.16-17.12-10.04-33.3-23.44-33.3-11.95 0-17.08 13.02-21.31 26.36-.48 1.5-1.41 4.55-3.94 13.05-.32 1.07-.62 2.13-.92 3.18-2.15 7.55-4.01 14.08-8.73 14.08-4.54 0-6.85-7.09-8.83-14.35-.81-2.99-4.11-14.12-4.51-15.4-4.29-13.62-9.47-26.93-21.49-26.93-13.4 0-18.28 16.18-23.44 33.31-2.55 8.44-7.28 24.16-11.19 24.29l-4.52-.11v12.69l4.21.1c13.6 0 18.48-16.18 23.64-33.31.66-2.2 1.25-4.54 1.82-6.8 2.15-8.52 4.18-16.56 9.47-16.56 5.03 0 7.4 8.93 9.49 16.81.1.38 3.51 11.92 4.35 14.52 3.95 12.26 9.15 25.34 20.98 25.34 11.95 0 17.06-12.95 21.27-26.22.74-2.33 4.27-14.12 4.55-15.15 2.16-8.07 4.49-15.3 9.08-15.3 5.29 0 7.32 8.04 9.47 16.56.57 2.26 1.16 4.6 1.82 6.8 5.17 17.13 10.05 33.31 23.68 33.3l4.17-.1V508.5l-4.42.13z"/><circle class="cls-79" cx="290.35" cy="488.04" r="119.5" stroke-width="21" stroke-dasharray="750.84" stroke-dashoffset="562" fill="none" stroke-linecap="round"/><circle class="st57" r="13.79"><animateMotion path="M290.35,368.77 a 119.5,119.5 0 1,1 0,239 a 119.5,119.5 0 1,1 0,-239" calcMode="linear" fill="freeze" dur="2s" keyTimes="0;1" keyPoints="0;',
          _percentage == 100 ? '1' : '0.',
          _percentage < 10 ? '0' : '',
          _percentage == 100 ? '' : _percentage.toString(),
          '"/></circle>'
        )
      );
  }

  function _amountToReadable(
    uint256 _amount,
    uint8 _decimals,
    string memory _symbol
  ) private pure returns (string memory) {
    return string(abi.encodePacked(DescriptorUtils.fixedPointToDecimalString(_amount, _decimals), ' ', _symbol));
  }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.7 <0.9.0;

import '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import '@mean-finance/oracles/solidity/interfaces/ITokenPriceOracle.sol';
import './IDCAPermissionManager.sol';

/**
 * @title The interface for all state related queries
 * @notice These methods allow users to read the hubs's current values
 */
interface IDCAHubParameters {
  /**
   * @notice Returns how much will the amount to swap differ from the previous swap. f.e. if the returned value is -100, then the amount to swap will be 100 less than the swap just before it
   * @dev `tokenA` must be smaller than `tokenB` (tokenA < tokenB)
   * @param tokenA One of the pair's token
   * @param tokenB The other of the pair's token
   * @param swapIntervalMask The byte representation of the swap interval to check
   * @param swapNumber The swap number to check
   * @return swapDeltaAToB How much less of token A will the following swap require
   * @return swapDeltaBToA How much less of token B will the following swap require
   */
  function swapAmountDelta(
    address tokenA,
    address tokenB,
    bytes1 swapIntervalMask,
    uint32 swapNumber
  ) external view returns (uint128 swapDeltaAToB, uint128 swapDeltaBToA);

  /**
   * @notice Returns the sum of the ratios reported in all swaps executed until the given swap number
   * @dev `tokenA` must be smaller than `tokenB` (tokenA < tokenB)
   * @param tokenA One of the pair's token
   * @param tokenB The other of the pair's token
   * @param swapIntervalMask The byte representation of the swap interval to check
   * @param swapNumber The swap number to check
   * @return accumRatioAToB The sum of all ratios from A to B
   * @return accumRatioBToA The sum of all ratios from B to A
   */
  function accumRatio(
    address tokenA,
    address tokenB,
    bytes1 swapIntervalMask,
    uint32 swapNumber
  ) external view returns (uint256 accumRatioAToB, uint256 accumRatioBToA);

  /**
   * @notice Returns swapping information about a specific pair
   * @dev `tokenA` must be smaller than `tokenB` (tokenA < tokenB)
   * @param tokenA One of the pair's token
   * @param tokenB The other of the pair's token
   * @param swapIntervalMask The byte representation of the swap interval to check
   * @return performedSwaps How many swaps have been executed
   * @return nextAmountToSwapAToB How much of token A will be swapped on the next swap
   * @return lastSwappedAt Timestamp of the last swap
   * @return nextAmountToSwapBToA How much of token B will be swapped on the next swap
   */
  function swapData(
    address tokenA,
    address tokenB,
    bytes1 swapIntervalMask
  )
    external
    view
    returns (
      uint32 performedSwaps,
      uint224 nextAmountToSwapAToB,
      uint32 lastSwappedAt,
      uint224 nextAmountToSwapBToA
    );

  /**
   * @notice Returns the byte representation of the set of actice swap intervals for the given pair
   * @dev `tokenA` must be smaller than `tokenB` (tokenA < tokenB)
   * @param tokenA The smaller of the pair's token
   * @param tokenB The other of the pair's token
   * @return The byte representation of the set of actice swap intervals
   */
  function activeSwapIntervals(address tokenA, address tokenB) external view returns (bytes1);

  /**
   * @notice Returns how much of the hub's token balance belongs to the platform
   * @param token The token to check
   * @return The amount that belongs to the platform
   */
  function platformBalance(address token) external view returns (uint256);
}

/**
 * @title The interface for all position related matters
 * @notice These methods allow users to create, modify and terminate their positions
 */
interface IDCAHubPositionHandler {
  /// @notice The position of a certain user
  struct UserPosition {
    // The token that the user deposited and will be swapped in exchange for "to"
    IERC20Metadata from;
    // The token that the user will get in exchange for their "from" tokens in each swap
    IERC20Metadata to;
    // How frequently the position's swaps should be executed
    uint32 swapInterval;
    // How many swaps were executed since deposit, last modification, or last withdraw
    uint32 swapsExecuted;
    // How many "to" tokens can currently be withdrawn
    uint256 swapped;
    // How many swaps left the position has to execute
    uint32 swapsLeft;
    // How many "from" tokens there are left to swap
    uint256 remaining;
    // How many "from" tokens need to be traded in each swap
    uint120 rate;
  }

  /// @notice A list of positions that all have the same `to` token
  struct PositionSet {
    // The `to` token
    address token;
    // The position ids
    uint256[] positionIds;
  }

  /**
   * @notice Emitted when a position is terminated
   * @param user The address of the user that terminated the position
   * @param recipientUnswapped The address of the user that will receive the unswapped tokens
   * @param recipientSwapped The address of the user that will receive the swapped tokens
   * @param positionId The id of the position that was terminated
   * @param returnedUnswapped How many "from" tokens were returned to the caller
   * @param returnedSwapped How many "to" tokens were returned to the caller
   */
  event Terminated(
    address indexed user,
    address indexed recipientUnswapped,
    address indexed recipientSwapped,
    uint256 positionId,
    uint256 returnedUnswapped,
    uint256 returnedSwapped
  );

  /**
   * @notice Emitted when a position is created
   * @param depositor The address of the user that creates the position
   * @param owner The address of the user that will own the position
   * @param positionId The id of the position that was created
   * @param fromToken The address of the "from" token
   * @param toToken The address of the "to" token
   * @param swapInterval How frequently the position's swaps should be executed
   * @param rate How many "from" tokens need to be traded in each swap
   * @param startingSwap The number of the swap when the position will be executed for the first time
   * @param lastSwap The number of the swap when the position will be executed for the last time
   * @param permissions The permissions defined for the position
   */
  event Deposited(
    address indexed depositor,
    address indexed owner,
    uint256 positionId,
    address fromToken,
    address toToken,
    uint32 swapInterval,
    uint120 rate,
    uint32 startingSwap,
    uint32 lastSwap,
    IDCAPermissionManager.PermissionSet[] permissions
  );

  /**
   * @notice Emitted when a position is created and extra data is provided
   * @param positionId The id of the position that was created
   * @param data The extra data that was provided
   */
  event Miscellaneous(uint256 positionId, bytes data);

  /**
   * @notice Emitted when a user withdraws all swapped tokens from a position
   * @param withdrawer The address of the user that executed the withdraw
   * @param recipient The address of the user that will receive the withdrawn tokens
   * @param positionId The id of the position that was affected
   * @param token The address of the withdrawn tokens. It's the same as the position's "to" token
   * @param amount The amount that was withdrawn
   */
  event Withdrew(address indexed withdrawer, address indexed recipient, uint256 positionId, address token, uint256 amount);

  /**
   * @notice Emitted when a user withdraws all swapped tokens from many positions
   * @param withdrawer The address of the user that executed the withdraws
   * @param recipient The address of the user that will receive the withdrawn tokens
   * @param positions The positions to withdraw from
   * @param withdrew The total amount that was withdrawn from each token
   */
  event WithdrewMany(address indexed withdrawer, address indexed recipient, PositionSet[] positions, uint256[] withdrew);

  /**
   * @notice Emitted when a position is modified
   * @param user The address of the user that modified the position
   * @param positionId The id of the position that was modified
   * @param rate How many "from" tokens need to be traded in each swap
   * @param startingSwap The number of the swap when the position will be executed for the first time
   * @param lastSwap The number of the swap when the position will be executed for the last time
   */
  event Modified(address indexed user, uint256 positionId, uint120 rate, uint32 startingSwap, uint32 lastSwap);

  /// @notice Thrown when a user tries to create a position with the same `from` & `to`
  error InvalidToken();

  /// @notice Thrown when a user tries to create a position with a swap interval that is not allowed
  error IntervalNotAllowed();

  /// @notice Thrown when a user tries operate on a position that doesn't exist (it might have been already terminated)
  error InvalidPosition();

  /// @notice Thrown when a user tries operate on a position that they don't have access to
  error UnauthorizedCaller();

  /// @notice Thrown when a user tries to create a position with zero swaps
  error ZeroSwaps();

  /// @notice Thrown when a user tries to create a position with zero funds
  error ZeroAmount();

  /// @notice Thrown when a user tries to withdraw a position whose `to` token doesn't match the specified one
  error PositionDoesNotMatchToken();

  /// @notice Thrown when a user tries create or modify a position with an amount too big
  error AmountTooBig();

  /**
   * @notice Returns the permission manager contract
   * @return The contract itself
   */
  function permissionManager() external view returns (IDCAPermissionManager);

  /**
   * @notice Returns total created positions
   * @return The total created positions
   */
  function totalCreatedPositions() external view returns (uint256);

  /**
   * @notice Returns a user position
   * @param positionId The id of the position
   * @return position The position itself
   */
  function userPosition(uint256 positionId) external view returns (UserPosition memory position);

  /**
   * @notice Creates a new position
   * @dev Will revert:
   *      - With ZeroAddress if from, to or owner are zero
   *      - With InvalidToken if from == to
   *      - With ZeroAmount if amount is zero
   *      - With AmountTooBig if amount is too big
   *      - With ZeroSwaps if amountOfSwaps is zero
   *      - With IntervalNotAllowed if swapInterval is not allowed
   * @param from The address of the "from" token
   * @param to The address of the "to" token
   * @param amount How many "from" tokens will be swapped in total
   * @param amountOfSwaps How many swaps to execute for this position
   * @param swapInterval How frequently the position's swaps should be executed
   * @param owner The address of the owner of the position being created
   * @param permissions Extra permissions to add to the position. Can be empty
   * @return positionId The id of the created position
   */
  function deposit(
    address from,
    address to,
    uint256 amount,
    uint32 amountOfSwaps,
    uint32 swapInterval,
    address owner,
    IDCAPermissionManager.PermissionSet[] calldata permissions
  ) external returns (uint256 positionId);

  /**
   * @notice Creates a new position
   * @dev Will revert:
   *      - With ZeroAddress if from, to or owner are zero
   *      - With InvalidToken if from == to
   *      - With ZeroAmount if amount is zero
   *      - With AmountTooBig if amount is too big
   *      - With ZeroSwaps if amountOfSwaps is zero
   *      - With IntervalNotAllowed if swapInterval is not allowed
   * @param from The address of the "from" token
   * @param to The address of the "to" token
   * @param amount How many "from" tokens will be swapped in total
   * @param amountOfSwaps How many swaps to execute for this position
   * @param swapInterval How frequently the position's swaps should be executed
   * @param owner The address of the owner of the position being created
   * @param permissions Extra permissions to add to the position. Can be empty
   * @param miscellaneous Bytes that will be emitted, and associated with the position
   * @return positionId The id of the created position
   */
  function deposit(
    address from,
    address to,
    uint256 amount,
    uint32 amountOfSwaps,
    uint32 swapInterval,
    address owner,
    IDCAPermissionManager.PermissionSet[] calldata permissions,
    bytes calldata miscellaneous
  ) external returns (uint256 positionId);

  /**
   * @notice Withdraws all swapped tokens from a position to a recipient
   * @dev Will revert:
   *      - With InvalidPosition if positionId is invalid
   *      - With UnauthorizedCaller if the caller doesn't have access to the position
   *      - With ZeroAddress if recipient is zero
   * @param positionId The position's id
   * @param recipient The address to withdraw swapped tokens to
   * @return swapped How much was withdrawn
   */
  function withdrawSwapped(uint256 positionId, address recipient) external returns (uint256 swapped);

  /**
   * @notice Withdraws all swapped tokens from multiple positions
   * @dev Will revert:
   *      - With InvalidPosition if any of the position ids are invalid
   *      - With UnauthorizedCaller if the caller doesn't have access to the position to any of the given positions
   *      - With ZeroAddress if recipient is zero
   *      - With PositionDoesNotMatchToken if any of the positions do not match the token in their position set
   * @param positions A list positions, grouped by `to` token
   * @param recipient The address to withdraw swapped tokens to
   * @return withdrawn How much was withdrawn for each token
   */
  function withdrawSwappedMany(PositionSet[] calldata positions, address recipient) external returns (uint256[] memory withdrawn);

  /**
   * @notice Takes the unswapped balance, adds the new deposited funds and modifies the position so that
   * it is executed in newSwaps swaps
   * @dev Will revert:
   *      - With InvalidPosition if positionId is invalid
   *      - With UnauthorizedCaller if the caller doesn't have access to the position
   *      - With AmountTooBig if amount is too big
   * @param positionId The position's id
   * @param amount Amount of funds to add to the position
   * @param newSwaps The new amount of swaps
   */
  function increasePosition(
    uint256 positionId,
    uint256 amount,
    uint32 newSwaps
  ) external;

  /**
   * @notice Withdraws the specified amount from the unswapped balance and modifies the position so that
   * it is executed in newSwaps swaps
   * @dev Will revert:
   *      - With InvalidPosition if positionId is invalid
   *      - With UnauthorizedCaller if the caller doesn't have access to the position
   *      - With ZeroSwaps if newSwaps is zero and amount is not the total unswapped balance
   * @param positionId The position's id
   * @param amount Amount of funds to withdraw from the position
   * @param newSwaps The new amount of swaps
   * @param recipient The address to send tokens to
   */
  function reducePosition(
    uint256 positionId,
    uint256 amount,
    uint32 newSwaps,
    address recipient
  ) external;

  /**
   * @notice Terminates the position and sends all unswapped and swapped balance to the specified recipients
   * @dev Will revert:
   *      - With InvalidPosition if positionId is invalid
   *      - With UnauthorizedCaller if the caller doesn't have access to the position
   *      - With ZeroAddress if recipientUnswapped or recipientSwapped is zero
   * @param positionId The position's id
   * @param recipientUnswapped The address to withdraw unswapped tokens to
   * @param recipientSwapped The address to withdraw swapped tokens to
   * @return unswapped The unswapped balance sent to `recipientUnswapped`
   * @return swapped The swapped balance sent to `recipientSwapped`
   */
  function terminate(
    uint256 positionId,
    address recipientUnswapped,
    address recipientSwapped
  ) external returns (uint256 unswapped, uint256 swapped);
}

/**
 * @title The interface for all swap related matters
 * @notice These methods allow users to get information about the next swap, and how to execute it
 */
interface IDCAHubSwapHandler {
  /// @notice Information about a swap
  struct SwapInfo {
    // The tokens involved in the swap
    TokenInSwap[] tokens;
    // The pairs involved in the swap
    PairInSwap[] pairs;
  }

  /// @notice Information about a token's role in a swap
  struct TokenInSwap {
    // The token's address
    address token;
    // How much will be given of this token as a reward
    uint256 reward;
    // How much of this token needs to be provided by swapper
    uint256 toProvide;
    // How much of this token will be paid to the platform
    uint256 platformFee;
  }

  /// @notice Information about a pair in a swap
  struct PairInSwap {
    // The address of one of the tokens
    address tokenA;
    // The address of the other token
    address tokenB;
    // The total amount of token A swapped in this pair
    uint256 totalAmountToSwapTokenA;
    // The total amount of token B swapped in this pair
    uint256 totalAmountToSwapTokenB;
    // How much is 1 unit of token A when converted to B
    uint256 ratioAToB;
    // How much is 1 unit of token B when converted to A
    uint256 ratioBToA;
    // The swap intervals involved in the swap, represented as a byte
    bytes1 intervalsInSwap;
  }

  /// @notice A pair of tokens, represented by their indexes in an array
  struct PairIndexes {
    // The index of the token A
    uint8 indexTokenA;
    // The index of the token B
    uint8 indexTokenB;
  }

  /**
   * @notice Emitted when a swap is executed
   * @param sender The address of the user that initiated the swap
   * @param rewardRecipient The address that received the reward
   * @param callbackHandler The address that executed the callback
   * @param swapInformation All information related to the swap
   * @param borrowed How much was borrowed
   * @param fee The swap fee at the moment of the swap
   */
  event Swapped(
    address indexed sender,
    address indexed rewardRecipient,
    address indexed callbackHandler,
    SwapInfo swapInformation,
    uint256[] borrowed,
    uint32 fee
  );

  /// @notice Thrown when pairs indexes are not sorted correctly
  error InvalidPairs();

  /// @notice Thrown when trying to execute a swap, but there is nothing to swap
  error NoSwapsToExecute();

  /**
   * @notice Returns all information related to the next swap
   * @dev Will revert with:
   *      - With InvalidTokens if tokens are not sorted, or if there are duplicates
   *      - With InvalidPairs if pairs are not sorted (first by indexTokenA and then indexTokenB), or if indexTokenA >= indexTokenB for any pair
   * @param tokens The tokens involved in the next swap
   * @param pairs The pairs that you want to swap. Each element of the list points to the index of the token in the tokens array
   * @param calculatePrivilegedAvailability Some accounts get privileged availability and can execute swaps before others. This flag provides
   *        the possibility to calculate the next swap information for privileged and non-privileged accounts
   * @param oracleData Bytes to send to the oracle when executing a quote
   * @return swapInformation The information about the next swap
   */
  function getNextSwapInfo(
    address[] calldata tokens,
    PairIndexes[] calldata pairs,
    bool calculatePrivilegedAvailability,
    bytes calldata oracleData
  ) external view returns (SwapInfo memory swapInformation);

  /**
   * @notice Executes a flash swap
   * @dev Will revert with:
   *      - With InvalidTokens if tokens are not sorted, or if there are duplicates
   *      - With InvalidPairs if pairs are not sorted (first by indexTokenA and then indexTokenB), or if indexTokenA >= indexTokenB for any pair
   *      - With Paused if swaps are paused by protocol
   *      - With NoSwapsToExecute if there are no swaps to execute for the given pairs
   *      - With LiquidityNotReturned if the required tokens were not back during the callback
   * @param tokens The tokens involved in the next swap
   * @param pairsToSwap The pairs that you want to swap. Each element of the list points to the index of the token in the tokens array
   * @param rewardRecipient The address to send the reward to
   * @param callbackHandler Address to call for callback (and send the borrowed tokens to)
   * @param borrow How much to borrow of each of the tokens in tokens. The amount must match the position of the token in the tokens array
   * @param callbackData Bytes to send to the caller during the callback
   * @param oracleData Bytes to send to the oracle when executing a quote
   * @return Information about the executed swap
   */
  function swap(
    address[] calldata tokens,
    PairIndexes[] calldata pairsToSwap,
    address rewardRecipient,
    address callbackHandler,
    uint256[] calldata borrow,
    bytes calldata callbackData,
    bytes calldata oracleData
  ) external returns (SwapInfo memory);
}

/**
 * @title The interface for handling all configuration
 * @notice This contract will manage configuration that affects all pairs, swappers, etc
 */
interface IDCAHubConfigHandler {
  /**
   * @notice Emitted when a new oracle is set
   * @param oracle The new oracle contract
   */
  event OracleSet(ITokenPriceOracle oracle);

  /**
   * @notice Emitted when a new swap fee is set
   * @param feeSet The new swap fee
   */
  event SwapFeeSet(uint32 feeSet);

  /**
   * @notice Emitted when new swap intervals are allowed
   * @param swapIntervals The new swap intervals
   */
  event SwapIntervalsAllowed(uint32[] swapIntervals);

  /**
   * @notice Emitted when some swap intervals are no longer allowed
   * @param swapIntervals The swap intervals that are no longer allowed
   */
  event SwapIntervalsForbidden(uint32[] swapIntervals);

  /**
   * @notice Emitted when a new platform fee ratio is set
   * @param platformFeeRatio The new platform fee ratio
   */
  event PlatformFeeRatioSet(uint16 platformFeeRatio);

  /**
   * @notice Emitted when allowed states of tokens are updated
   * @param tokens Array of updated tokens
   * @param allowed Array of new allow state per token were allowed[i] is the updated state of tokens[i]
   */
  event TokensAllowedUpdated(address[] tokens, bool[] allowed);

  /// @notice Thrown when trying to interact with an unallowed token
  error UnallowedToken();

  /// @notice Thrown when set allowed tokens input is not valid
  error InvalidAllowedTokensInput();

  /// @notice Thrown when trying to set a fee higher than the maximum allowed
  error HighFee();

  /// @notice Thrown when trying to set a fee that is not multiple of 100
  error InvalidFee();

  /// @notice Thrown when trying to set a fee ratio that is higher that the maximum allowed
  error HighPlatformFeeRatio();

  /**
   * @notice Returns the max fee ratio that can be set
   * @dev Cannot be modified
   * @return The maximum possible value
   */
  // solhint-disable-next-line func-name-mixedcase
  function MAX_PLATFORM_FEE_RATIO() external view returns (uint16);

  /**
   * @notice Returns the fee charged on swaps
   * @return swapFee The fee itself
   */
  function swapFee() external view returns (uint32 swapFee);

  /**
   * @notice Returns the price oracle contract
   * @return oracle The contract itself
   */
  function oracle() external view returns (ITokenPriceOracle oracle);

  /**
   * @notice Returns how much will the platform take from the fees collected in swaps
   * @return The current ratio
   */
  function platformFeeRatio() external view returns (uint16);

  /**
   * @notice Returns the max fee that can be set for swaps
   * @dev Cannot be modified
   * @return maxFee The maximum possible fee
   */
  // solhint-disable-next-line func-name-mixedcase
  function MAX_FEE() external view returns (uint32 maxFee);

  /**
   * @notice Returns a byte that represents allowed swap intervals
   * @return allowedSwapIntervals The allowed swap intervals
   */
  function allowedSwapIntervals() external view returns (bytes1 allowedSwapIntervals);

  /**
   * @notice Returns if a token is currently allowed or not
   * @return Allowed state of token
   */
  function allowedTokens(address token) external view returns (bool);

  /**
   * @notice Returns token's magnitude (10**decimals)
   * @return Stored magnitude for token
   */
  function tokenMagnitude(address token) external view returns (uint120);

  /**
   * @notice Returns whether swaps and deposits are currently paused
   * @return isPaused Whether swaps and deposits are currently paused
   */
  function paused() external view returns (bool isPaused);

  /**
   * @notice Sets a new swap fee
   * @dev Will revert with HighFee if the fee is higher than the maximum
   * @dev Will revert with InvalidFee if the fee is not multiple of 100
   * @param fee The new swap fee
   */
  function setSwapFee(uint32 fee) external;

  /**
   * @notice Sets a new price oracle
   * @dev Will revert with ZeroAddress if the zero address is passed
   * @param oracle The new oracle contract
   */
  function setOracle(ITokenPriceOracle oracle) external;

  /**
   * @notice Sets a new platform fee ratio
   * @dev Will revert with HighPlatformFeeRatio if given ratio is too high
   * @param platformFeeRatio The new ratio
   */
  function setPlatformFeeRatio(uint16 platformFeeRatio) external;

  /**
   * @notice Adds new swap intervals to the allowed list
   * @param swapIntervals The new swap intervals
   */
  function addSwapIntervalsToAllowedList(uint32[] calldata swapIntervals) external;

  /**
   * @notice Removes some swap intervals from the allowed list
   * @param swapIntervals The swap intervals to remove
   */
  function removeSwapIntervalsFromAllowedList(uint32[] calldata swapIntervals) external;

  /// @notice Pauses all swaps and deposits
  function pause() external;

  /// @notice Unpauses all swaps and deposits
  function unpause() external;
}

/**
 * @title The interface for handling platform related actions
 * @notice This contract will handle all actions that affect the platform in some way
 */
interface IDCAHubPlatformHandler {
  /**
   * @notice Emitted when someone withdraws from the paltform balance
   * @param sender The address of the user that initiated the withdraw
   * @param recipient The address that received the withdraw
   * @param amounts The tokens (and the amount) that were withdrawn
   */
  event WithdrewFromPlatform(address indexed sender, address indexed recipient, IDCAHub.AmountOfToken[] amounts);

  /**
   * @notice Withdraws tokens from the platform balance
   * @param amounts The amounts to withdraw
   * @param recipient The address that will receive the tokens
   */
  function withdrawFromPlatformBalance(IDCAHub.AmountOfToken[] calldata amounts, address recipient) external;
}

interface IDCAHub is IDCAHubParameters, IDCAHubConfigHandler, IDCAHubSwapHandler, IDCAHubPositionHandler, IDCAHubPlatformHandler {
  /// @notice Specifies an amount of a token. For example to determine how much to borrow from certain tokens
  struct AmountOfToken {
    // The tokens' address
    address token;
    // How much to borrow or withdraw of the specified token
    uint256 amount;
  }

  /// @notice Thrown when one of the parameters is a zero address
  error ZeroAddress();

  /// @notice Thrown when the expected liquidity is not returned in flash swaps
  error LiquidityNotReturned();

  /// @notice Thrown when a list of token pairs is not sorted, or if there are duplicates
  error InvalidTokens();
}

// SPDX-License-Identifier: MIT

/// @title Base64
/// @author Brecht Devos - <[email protected]>
/// @notice Provides a function for encoding some bytes in base64
library Base64 {
    string internal constant TABLE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

    function encode(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return '';
        
        // load the table into memory
        string memory table = TABLE;

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((data.length + 2) / 3);

        // add some extra buffer at the end required for the writing
        string memory result = new string(encodedLen + 32);

        assembly {
            // set the actual output length
            mstore(result, encodedLen)
            
            // prepare the lookup table
            let tablePtr := add(table, 1)
            
            // input ptr
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))
            
            // result ptr, jump over length
            let resultPtr := add(result, 32)
            
            // run over the input, 3 bytes at a time
            for {} lt(dataPtr, endPtr) {}
            {
               dataPtr := add(dataPtr, 3)
               
               // read 3 bytes
               let input := mload(dataPtr)
               
               // write 4 characters
               mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr(18, input), 0x3F)))))
               resultPtr := add(resultPtr, 1)
               mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr(12, input), 0x3F)))))
               resultPtr := add(resultPtr, 1)
               mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr( 6, input), 0x3F)))))
               resultPtr := add(resultPtr, 1)
               mstore(resultPtr, shl(248, mload(add(tablePtr, and(        input,  0x3F)))))
               resultPtr := add(resultPtr, 1)
            }
            
            // padding with '='
            switch mod(mload(data), 3)
            case 1 { mstore(sub(resultPtr, 2), shl(240, 0x3d3d)) }
            case 2 { mstore(sub(resultPtr, 1), shl(248, 0x3d)) }
        }
        
        return result;
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.7 <0.9.0;

/**
 * @title The interface for generating a description for a position in a DCA Hub
 * @notice Contracts that implement this interface must return a base64 JSON with the entire description
 */
interface IDCAHubPositionDescriptor {
  /**
   * @notice Generates a positions's description, both the JSON and the image inside
   * @param hub The address of the DCA Hub
   * @param positionId The token/position id
   * @return description The position's description
   */
  function tokenURI(address hub, uint256 positionId) external view returns (string memory description);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import '@openzeppelin/contracts/utils/Strings.sol';

// Based on Uniswap's NFTDescriptor
library DescriptorUtils {
  using Strings for uint256;
  using Strings for uint32;

  function fixedPointToDecimalString(uint256 _value, uint8 _decimals) internal pure returns (string memory) {
    if (_value == 0) {
      return '0.0000';
    }

    bool _priceBelow1 = _value < 10**_decimals;

    // get digit count
    uint256 _temp = _value;
    uint8 _digits;
    while (_temp != 0) {
      _digits++;
      _temp /= 10;
    }
    // don't count extra digit kept for rounding
    _digits = _digits - 1;

    // address rounding
    (uint256 _sigfigs, bool _extraDigit) = _sigfigsRounded(_value, _digits);
    if (_extraDigit) {
      _digits++;
    }

    DecimalStringParams memory _params;
    if (_priceBelow1) {
      // 7 bytes ( "0." and 5 sigfigs) + leading 0's bytes
      _params.bufferLength = _digits >= 5 ? _decimals - _digits + 6 : _decimals + 2;
      _params.zerosStartIndex = 2;
      _params.zerosEndIndex = _decimals - _digits + 1;
      _params.sigfigIndex = _params.bufferLength - 1;
    } else if (_digits >= _decimals + 4) {
      // no decimal in price string
      _params.bufferLength = _digits - _decimals + 1;
      _params.zerosStartIndex = 5;
      _params.zerosEndIndex = _params.bufferLength - 1;
      _params.sigfigIndex = 4;
    } else {
      // 5 sigfigs surround decimal
      _params.bufferLength = 6;
      _params.sigfigIndex = 5;
      _params.decimalIndex = _digits - _decimals + 1;
    }
    _params.sigfigs = _sigfigs;
    _params.isLessThanOne = _priceBelow1;

    return _generateDecimalString(_params);
  }

  function addressToString(address _addr) internal pure returns (string memory) {
    bytes memory _s = new bytes(40);
    for (uint256 _i = 0; _i < 20; _i++) {
      bytes1 _b = bytes1(uint8(uint256(uint160(_addr)) / (2**(8 * (19 - _i)))));
      bytes1 _hi = bytes1(uint8(_b) / 16);
      bytes1 _lo = bytes1(uint8(_b) - 16 * uint8(_hi));
      _s[2 * _i] = _char(_hi);
      _s[2 * _i + 1] = _char(_lo);
    }
    return string(abi.encodePacked('0x', string(_s)));
  }

  struct DecimalStringParams {
    // significant figures of decimal
    uint256 sigfigs;
    // length of decimal string
    uint8 bufferLength;
    // ending index for significant figures (funtion works backwards when copying sigfigs)
    uint8 sigfigIndex;
    // index of decimal place (0 if no decimal)
    uint8 decimalIndex;
    // start index for trailing/leading 0's for very small/large numbers
    uint8 zerosStartIndex;
    // end index for trailing/leading 0's for very small/large numbers
    uint8 zerosEndIndex;
    // true if decimal number is less than one
    bool isLessThanOne;
  }

  function _generateDecimalString(DecimalStringParams memory _params) private pure returns (string memory) {
    bytes memory _buffer = new bytes(_params.bufferLength);
    if (_params.isLessThanOne) {
      _buffer[0] = '0';
      _buffer[1] = '.';
    }

    // add leading/trailing 0's
    for (uint256 _zerosCursor = _params.zerosStartIndex; _zerosCursor < _params.zerosEndIndex + 1; _zerosCursor++) {
      _buffer[_zerosCursor] = bytes1(uint8(48));
    }
    // add sigfigs
    while (_params.sigfigs > 0) {
      if (_params.decimalIndex > 0 && _params.sigfigIndex == _params.decimalIndex) {
        _buffer[_params.sigfigIndex--] = '.';
      }
      uint8 _charIndex = uint8(48 + (_params.sigfigs % 10));
      _buffer[_params.sigfigIndex] = bytes1(_charIndex);
      _params.sigfigs /= 10;
      if (_params.sigfigs > 0) {
        _params.sigfigIndex--;
      }
    }
    return string(_buffer);
  }

  function _sigfigsRounded(uint256 _value, uint8 _digits) private pure returns (uint256, bool) {
    bool _extraDigit;
    if (_digits > 5) {
      _value = _value / (10**(_digits - 5));
    }
    bool _roundUp = _value % 10 > 4;
    _value = _value / 10;
    if (_roundUp) {
      _value = _value + 1;
    }
    // 99999 -> 100000 gives an extra sigfig
    if (_value == 100000) {
      _value /= 10;
      _extraDigit = true;
    }
    return (_value, _extraDigit);
  }

  function _char(bytes1 _b) private pure returns (bytes1) {
    if (uint8(_b) < 10) return bytes1(uint8(_b) + 0x30);
    else return bytes1(uint8(_b) + 0x57);
  }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

library IntervalUtils {
  /// @notice Thrown when a user tries get the description of an unsupported interval
  error InvalidInterval();

  function intervalToDescription(uint32 _swapInterval) internal pure returns (string memory) {
    if (_swapInterval == 1 minutes) return 'Every minute';
    if (_swapInterval == 5 minutes) return 'Every 5 minutes';
    if (_swapInterval == 15 minutes) return 'Every 15 minutes';
    if (_swapInterval == 30 minutes) return 'Every 30 minutes';
    if (_swapInterval == 1 hours) return 'Hourly';
    if (_swapInterval == 4 hours) return 'Every 4 hours';
    if (_swapInterval == 1 days) return 'Daily';
    if (_swapInterval == 1 weeks) return 'Weekly';
    revert InvalidInterval();
  }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/**
 * @title The interface for an oracle that provides price quotes
 * @notice These methods allow users to add support for pairs, and then ask for quotes
 */
interface ITokenPriceOracle {
  /// @notice Thrown when trying to add support for a pair that cannot be supported
  error PairCannotBeSupported(address tokenA, address tokenB);

  /// @notice Thrown when trying to execute a quote with a pair that isn't supported yet
  error PairNotSupportedYet(address tokenA, address tokenB);

  /**
   * @notice Returns whether this oracle can support the given pair of tokens
   * @dev tokenA and tokenB may be passed in either tokenA/tokenB or tokenB/tokenA order
   * @param tokenA One of the pair's tokens
   * @param tokenB The other of the pair's tokens
   * @return Whether the given pair of tokens can be supported by the oracle
   */
  function canSupportPair(address tokenA, address tokenB) external view returns (bool);

  /**
   * @notice Returns whether this oracle is already supporting the given pair of tokens
   * @dev tokenA and tokenB may be passed in either tokenA/tokenB or tokenB/tokenA order
   * @param tokenA One of the pair's tokens
   * @param tokenB The other of the pair's tokens
   * @return Whether the given pair of tokens is already being supported by the oracle
   */
  function isPairAlreadySupported(address tokenA, address tokenB) external view returns (bool);

  /**
   * @notice Returns a quote, based on the given tokens and amount
   * @dev Will revert if pair isn't supported
   * @param tokenIn The token that will be provided
   * @param amountIn The amount that will be provided
   * @param tokenOut The token we would like to quote
   * @param data Custom data that the oracle might need to operate
   * @return amountOut How much `tokenOut` will be returned in exchange for `amountIn` amount of `tokenIn`
   */
  function quote(
    address tokenIn,
    uint256 amountIn,
    address tokenOut,
    bytes calldata data
  ) external view returns (uint256 amountOut);

  /**
   * @notice Add or reconfigures the support for a given pair. This function will let the oracle take some actions
   *         to configure the pair, in preparation for future quotes. Can be called many times in order to let the oracle
   *         re-configure for a new context
   * @dev Will revert if pair cannot be supported. tokenA and tokenB may be passed in either tokenA/tokenB or tokenB/tokenA order
   * @param tokenA One of the pair's tokens
   * @param tokenB The other of the pair's tokens
   * @param data Custom data that the oracle might need to operate
   */
  function addOrModifySupportForPair(
    address tokenA,
    address tokenB,
    bytes calldata data
  ) external;

  /**
   * @notice Adds support for a given pair if the oracle didn't support it already. If called for a pair that is already supported,
   *         then nothing will happen. This function will let the oracle take some actions to configure the pair, in preparation
   *         for future quotes
   * @dev Will revert if pair cannot be supported. tokenA and tokenB may be passed in either tokenA/tokenB or tokenB/tokenA order
   * @param tokenA One of the pair's tokens
   * @param tokenB The other of the pair's tokens
   * @param data Custom data that the oracle might need to operate
   */
  function addSupportForPairIfNeeded(
    address tokenA,
    address tokenB,
    bytes calldata data
  ) external;
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.7 <0.9.0;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@mean-finance/nft-descriptors/solidity/interfaces/IDCAHubPositionDescriptor.sol';

interface IERC721BasicEnumerable {
  /**
   * @notice Count NFTs tracked by this contract
   * @return A count of valid NFTs tracked by this contract, where each one of
   *         them has an assigned and queryable owner not equal to the zero address
   */
  function totalSupply() external view returns (uint256);
}

/**
 * @title The interface for all permission related matters
 * @notice These methods allow users to set and remove permissions to their positions
 */
interface IDCAPermissionManager is IERC721, IERC721BasicEnumerable {
  /// @notice Set of possible permissions
  enum Permission {
    INCREASE,
    REDUCE,
    WITHDRAW,
    TERMINATE
  }

  /// @notice A set of permissions for a specific operator
  struct PermissionSet {
    // The address of the operator
    address operator;
    // The permissions given to the overator
    Permission[] permissions;
  }

  /// @notice A collection of permissions sets for a specific position
  struct PositionPermissions {
    // The id of the token
    uint256 tokenId;
    // The permissions to assign to the position
    PermissionSet[] permissionSets;
  }

  /**
   * @notice Emitted when permissions for a token are modified
   * @param tokenId The id of the token
   * @param permissions The set of permissions that were updated
   */
  event Modified(uint256 tokenId, PermissionSet[] permissions);

  /**
   * @notice Emitted when the address for a new descritor is set
   * @param descriptor The new descriptor contract
   */
  event NFTDescriptorSet(IDCAHubPositionDescriptor descriptor);

  /// @notice Thrown when a user tries to set the hub, once it was already set
  error HubAlreadySet();

  /// @notice Thrown when a user provides a zero address when they shouldn't
  error ZeroAddress();

  /// @notice Thrown when a user calls a method that can only be executed by the hub
  error OnlyHubCanExecute();

  /// @notice Thrown when a user tries to modify permissions for a token they do not own
  error NotOwner();

  /// @notice Thrown when a user tries to execute a permit with an expired deadline
  error ExpiredDeadline();

  /// @notice Thrown when a user tries to execute a permit with an invalid signature
  error InvalidSignature();

  /**
   * @notice The permit typehash used in the permit signature
   * @return The typehash for the permit
   */
  // solhint-disable-next-line func-name-mixedcase
  function PERMIT_TYPEHASH() external pure returns (bytes32);

  /**
   * @notice The permit typehash used in the permission permit signature
   * @return The typehash for the permission permit
   */
  // solhint-disable-next-line func-name-mixedcase
  function PERMISSION_PERMIT_TYPEHASH() external pure returns (bytes32);

  /**
   * @notice The permit typehash used in the multi permission permit signature
   * @return The typehash for the multi permission permit
   */
  // solhint-disable-next-line func-name-mixedcase
  function MULTI_PERMISSION_PERMIT_TYPEHASH() external pure returns (bytes32);

  /**
   * @notice The permit typehash used in the permission permit signature
   * @return The typehash for the permission set
   */
  // solhint-disable-next-line func-name-mixedcase
  function PERMISSION_SET_TYPEHASH() external pure returns (bytes32);

  /**
   * @notice The permit typehash used in the multi permission permit signature
   * @return The typehash for the position permissions
   */
  // solhint-disable-next-line func-name-mixedcase
  function POSITION_PERMISSIONS_TYPEHASH() external pure returns (bytes32);

  /**
   * @notice The domain separator used in the permit signature
   * @return The domain seperator used in encoding of permit signature
   */
  // solhint-disable-next-line func-name-mixedcase
  function DOMAIN_SEPARATOR() external view returns (bytes32);

  /**
   * @notice Returns the NFT descriptor contract
   * @return The contract for the NFT descriptor
   */
  function nftDescriptor() external returns (IDCAHubPositionDescriptor);

  /**
   * @notice Returns the address of the DCA Hub
   * @return The address of the DCA Hub
   */
  function hub() external returns (address);

  /**
   * @notice Returns the next nonce to use for a given user
   * @param user The address of the user
   * @return nonce The next nonce to use
   */
  function nonces(address user) external returns (uint256 nonce);

  /**
   * @notice Returns whether the given address has the permission for the given token
   * @param id The id of the token to check
   * @param account The address of the user to check
   * @param permission The permission to check
   * @return Whether the user has the permission or not
   */
  function hasPermission(
    uint256 id,
    address account,
    Permission permission
  ) external view returns (bool);

  /**
   * @notice Returns whether the given address has the permissions for the given token
   * @param id The id of the token to check
   * @param account The address of the user to check
   * @param permissions The permissions to check
   * @return hasPermissions Whether the user has each permission or not
   */
  function hasPermissions(
    uint256 id,
    address account,
    Permission[] calldata permissions
  ) external view returns (bool[] memory hasPermissions);

  /**
   * @notice Sets the address for the hub
   * @dev Can only be successfully executed once. Once it's set, it can be modified again
   *      Will revert:
   *      - With ZeroAddress if address is zero
   *      - With HubAlreadySet if the hub has already been set
   * @param hub The address to set for the hub
   */
  function setHub(address hub) external;

  /**
   * @notice Mints a new NFT with the given id, and sets the permissions for it
   * @dev Will revert with OnlyHubCanExecute if the caller is not the hub
   * @param id The id of the new NFT
   * @param owner The owner of the new NFT
   * @param permissions Permissions to set for the new NFT
   */
  function mint(
    uint256 id,
    address owner,
    PermissionSet[] calldata permissions
  ) external;

  /**
   * @notice Burns the NFT with the given id, and clears all permissions
   * @dev Will revert with OnlyHubCanExecute if the caller is not the hub
   * @param id The token's id
   */
  function burn(uint256 id) external;

  /**
   * @notice Sets new permissions for the given position
   * @dev Will revert with NotOwner if the caller is not the token's owner.
   *      Operators that are not part of the given permission sets do not see their permissions modified.
   *      In order to remove permissions to an operator, provide an empty list of permissions for them
   * @param id The token's id
   * @param permissions A list of permission sets
   */
  function modify(uint256 id, PermissionSet[] calldata permissions) external;

  /**
   * @notice Sets new permissions for the given positions
   * @dev This is basically the same as executing multiple `modify`
   * @param permissions A list of position permissions to set
   */
  function modifyMany(PositionPermissions[] calldata permissions) external;

  /**
   * @notice Approves spending of a specific token ID by spender via signature
   * @param spender The account that is being approved
   * @param tokenId The ID of the token that is being approved for spending
   * @param deadline The deadline timestamp by which the call must be mined for the approve to work
   * @param v Must produce valid secp256k1 signature from the holder along with `r` and `s`
   * @param r Must produce valid secp256k1 signature from the holder along with `v` and `s`
   * @param s Must produce valid secp256k1 signature from the holder along with `r` and `v`
   */
  function permit(
    address spender,
    uint256 tokenId,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external;

  /**
   * @notice Sets permissions via signature
   * @dev This method works similarly to `modifyMany`, but instead of being executed by the owner, it can be set by signature
   * @param permissions The permissions to set for the different positions
   * @param deadline The deadline timestamp by which the call must be mined for the approve to work
   * @param v Must produce valid secp256k1 signature from the holder along with `r` and `s`
   * @param r Must produce valid secp256k1 signature from the holder along with `v` and `s`
   * @param s Must produce valid secp256k1 signature from the holder along with `r` and `v`
   */
  function multiPermissionPermit(
    PositionPermissions[] calldata permissions,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external;

  /**
   * @notice Sets permissions via signature
   * @dev This method works similarly to `modify`, but instead of being executed by the owner, it can be set my signature
   * @param permissions The permissions to set
   * @param tokenId The token's id
   * @param deadline The deadline timestamp by which the call must be mined for the approve to work
   * @param v Must produce valid secp256k1 signature from the holder along with `r` and `s`
   * @param r Must produce valid secp256k1 signature from the holder along with `v` and `s`
   * @param s Must produce valid secp256k1 signature from the holder along with `r` and `v`
   */
  function permissionPermit(
    PermissionSet[] calldata permissions,
    uint256 tokenId,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external;

  /**
   * @notice Sets a new NFT descriptor
   * @dev Will revert with ZeroAddress if address is zero
   * @param descriptor The new NFT descriptor contract
   */
  function setNFTDescriptor(IDCAHubPositionDescriptor descriptor) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}