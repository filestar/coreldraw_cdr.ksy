meta:
  id: cmx3
  title: Corel Metafile Exchange Format
  application: CorelDRAW
  file-extension: cmx
  encoding: ASCII
  endian: le
# TODO: doc
seq:
  - id: magic
    size: 4
    type: str
    valid:
      any-of:
        - '"CMX3"'
        - '"RIFF"'
  - id: body
    type: body_new
    if: 'magic == "CMX3"'
types:
  body_new:
    seq:
      - id: len_format
        type: u4
      - id: format
        size: len_format
        type: format_data
      - id: unknown
        size: 8
      - id: chunks
        type: chunk
        repeat: eos
        if: not format.is_compressed
  format_data:
    seq:
      - id: len_format_string
        type: u4
      - id: format_string
        size: len_format_string
        type: str
      - id: is_compressed_raw
        type: u1
    instances:
      is_compressed:
        value: is_compressed_raw != 0
  chunk:
    seq:
      - id: chunk_id
        type: str
        size: 4
      - id: body
        type:
          switch-on: chunk_id
          cases:
            '"RCRS"': rcrs_chunk_data
            '"UDIM"': udim_chunk_data
            '"THUM"': thum_chunk_data
            '"CSTY"': csty_chunk_data
            '"RET!"': retx_chunk_data
            '"ATTR"': attr_chunk_data
            '"POLY"': poly_chunk_data
            '"DRAW"': draw_chunk_data
            '"META"': meta_chunk_data
            _: rest_of_chunks
  rcrs_chunk_data:
    seq:
      - id: unknown
        size: 4
  udim_chunk_data:
    seq:
      - id: unknown1
        size: 4
      - id: flags
        type: u1
      - id: unknown2
        size: 8
      - id: unknown3
        size: 3
        if: is_weird
      - id: len_body
        type: u4
        if: not is_weird
      - id: body
        type:
          # I'm currently guessing that `flags` contains bitflags that specify which
          # fields come next. But until I can figure out the scheme, this is the best I can do:
          switch-on: flags
          cases:
            0x58: render_properties
        size: 'is_weird ? 0 : len_body.as<u4>'
    instances:
      # TODO: this is a hack.
      is_weird:
        value: flags == 0x48 or flags == 0x0f or flags == 0x0c
    types:
      render_properties:
        seq:
          - id: len_color_context
            type: u4
          - id: color_context
            type: str
            size: len_color_context
          - id: unknown
            size: 3
  attr_chunk_data:
    seq:
      - id: unknown1
        size: 8
      - id: len_body
        type: u4
      - id: body
        type: attributes
        size: len_body
    types:
      attributes:
        seq:
          - id: unknown1
            size: 77
          - id: fill_color
            type: color
          - id: unknown2
            size-eos: true
      # TODO: this is copied from `color_new` in coreldraw_cdr.ksy; it should be moved to a shared spec instead, if possible
      color:
        seq:
          - id: color_model
            type: u2
            enum: color_model
          - id: color_palette
            type: u2
            enum: color_palette
          - id: unknown
            size: 4
          - id: color_value
            type: u1
            repeat: expr
            repeat-expr: 4
    # TODO: these enums are copy-pasted from coreldraw_cdr.ksy; they should be moved to a shared spec instead, if possible
    enums:
      color_model:
        1: pantone
        2: cmyk100
        3: cmyk255_i3
        4: cmy
        5: bgr
        6: hsb
        7: hls
        8: bw
        9: grayscale
        11: yiq255
        12:
          id: lab_signed_int8
          doc-ref: https://github.com/LibreOffice/libcdr/blob/b14f6a1f17652aa842b23c66236610aea5233aa6/src/lib/CDRCollector.cpp#L541-L554
        13:
          id: index
          doc-ref: CorelDRAW 9 Draw_scr.hlp
          doc: no longer present in CorelDRAW 10 DRAW10VBA.HLP
        14: pantone_hex
        15:
          id: hexachrome
          doc-ref: CorelDRAW 9 Draw_scr.hlp
          doc: no longer present in CorelDRAW 10 DRAW10VBA.HLP
        17: cmyk255_i17
        18:
          id: lab_offset_128
          doc-ref: https://github.com/LibreOffice/libcdr/blob/b14f6a1f17652aa842b23c66236610aea5233aa6/src/lib/CDRCollector.cpp#L555-L568
        20: registration
        21:
          id: bgr_tint
          # NOTE: libcdr treats color model `21` (0x15) as CMYK100
          # (https://github.com/LibreOffice/libcdr/blob/b14f6a1f17652aa842b23c66236610aea5233aa6/src/lib/CDRCollector.cpp#L339),
          # but that is clearly wrong according to sample files
          doc: |
            Seen only in `fild_chunk_data::solid` in a `property_type::color`
            property for "special palette" colors so far.

            color_value[0]: Blue (0..255)
            color_value[1]: Green (0..255)
            color_value[2]: Red (0..255)
            color_value[3]: Tint (0..100) - as in `color_model::spot`

            However, note that "Tint" has already been factored into the RGB
            value, so it's apparently just for reference.
        22:
          id: user_ink
          doc-ref: https://community.coreldraw.com/sdk/api/draw/17/e/cdrcolortype
        25: spot
        26:
          id: multi_channel
          doc-ref: https://community.coreldraw.com/sdk/api/draw/17/e/cdrcolortype
        99:
          id: mixed
          doc-ref: https://community.coreldraw.com/sdk/api/draw/17/e/cdrcolortype
      # CorelDRAW 9: Programs/Draw_scr.hlp, Programs/Data/*.{cpl,pcp}
      # CorelDRAW 10: Programs/DRAW10VBA.HLP, Programs/Data/*.cpl
      # CorelDRAW 11: Programs/DRAW11VBA.HLP, Programs/Data/*.cpl
      # CorelDRAW X7:
      #   - https://community.coreldraw.com/sdk/api/draw/17/e/cdrpaletteid
      #   - Color/Palettes/**/*.xml
      color_palette:
        0: custom
        1:
          id: trumatch
          doc: TRUMATCH Colors # palette name
        2:
          id: pantone_process
          -orig-id:
            - PANTONE PROCESS # CorelDRAW 9 Draw_scr.hlp
            - pantone # palette file name (without the .cpl/.xml extension)
          doc: PANTONE(r) process coated
        3:
          id: pantone_corel8
          -orig-id:
            - PANTONE SPOT # CorelDRAW 9 Draw_scr.hlp
            - cdrPANTONECorel8 # CorelDRAW 10 DRAW10VBA.HLP
            - pantone8
          doc: PANTONE MATCHING SYSTEM - Corel 8
        4:
          id: image
          -orig-id: IMAGE # CorelDRAW 9 Draw_scr.hlp, no longer in CorelDRAW 10 DRAW10VBA.HLP
        5:
          id: user
          -orig-id: USER # CorelDRAW 9 Draw_scr.hlp, no longer in CorelDRAW 10 DRAW10VBA.HLP
        6:
          id: custom_fixed
          -orig-id: CUSTOMFIXED # CorelDRAW 9 Draw_scr.hlp, no longer in CorelDRAW 10 DRAW10VBA.HLP
        7:
          id: uniform
          -orig-id:
            - RGBSTANDARD # CorelDRAW 9 Draw_scr.hlp
            - cdrUniform # CorelDRAW 10 DRAW10VBA.HLP
            - rgbstd
          doc: Uniform Colors
        8:
          id: focoltone
          -orig-id:
            - focolton
          doc: FOCOLTONE Colors
        9:
          id: spectra_master
          -orig-id:
            - DUPONT # CorelDRAW 9 Draw_scr.hlp
            - cdrSpectraMaster # CorelDRAW 10 DRAW10VBA.HLP
            - dupont
          doc: SpectraMaster(r) Colors
        10:
          id: toyo
          doc: TOYO COLOR FINDER
        11:
          id: dic
          doc: DIC Colors
        12:
          id: pantone_hex_coated_corel10
          -orig-id:
            - cdrPANTONEHexCoated # CorelDRAW 10 DRAW10VBA.HLP, no longer in CorelDRAW 11 DRAW11VBA.HLP
            - panhexc
          doc: PANTONE Hexachrome Coated - Corel 10
        13:
          id: lab
          -orig-id:
            - labpal
          doc: Lab Colors
        14:
          id: netscape
          -orig-id:
            - NETSCAPE # CorelDRAW 9 Draw_scr.hlp
            - cdrNetscapeNavigator # CorelDRAW 10 DRAW10VBA.HLP, no longer in CorelDRAW 11 DRAW11VBA.HLP
            - netscape # netscape.cpl is present in CorelDRAW 9, but not anymore in CorelDRAW 10
        15:
          id: explorer
          -orig-id:
            - EXPLORER # CorelDRAW 9 Draw_scr.hlp
            - cdrInternetExplorer # CorelDRAW 10 DRAW10VBA.HLP
            - explorer # explorer.cpl is present in CorelDRAW 9, but not anymore in CorelDRAW 10
          doc: no longer present in CorelDRAW 11 DRAW11VBA.HLP
        16: user_inks
        17:
          id: pantone_coated_corel10
          -orig-id:
            - cdrPANTONECoated # CorelDRAW 10 DRAW10VBA.HLP, no longer in CorelDRAW 11 DRAW11VBA.HLP
            - panguidc
          doc-ref: https://github.com/LibreOffice/libcdr/blob/b14f6a1f17652aa842b23c66236610aea5233aa6/src/lib/CDRColorPalettes.h#L2348
          doc: PANTONE MATCHING SYSTEM Coated - Corel 10
        18:
          id: pantone_uncoated_corel10
          -orig-id:
            - cdrPANTONEUncoated # CorelDRAW 10 DRAW10VBA.HLP, no longer in CorelDRAW 11 DRAW11VBA.HLP
            - panguidu
          doc-ref: https://github.com/LibreOffice/libcdr/blob/b14f6a1f17652aa842b23c66236610aea5233aa6/src/lib/CDRColorPalettes.h#L2630
          doc: PANTONE MATCHING SYSTEM Uncoated - Corel 10
        20:
          id: pantone_metallic_corel10
          -orig-id:
            - cdrPANTONEMetallic # CorelDRAW 10 DRAW10VBA.HLP, no longer in CorelDRAW 11 DRAW11VBA.HLP
            - panmetlu
          doc-ref: https://github.com/LibreOffice/libcdr/blob/b14f6a1f17652aa842b23c66236610aea5233aa6/src/lib/CDRColorPalettes.h#L2912
          doc: PANTONE Metallic Colors Unvarnished - Corel 10
        21:
          id: pantone_pastel_coated_corel10
          -orig-id:
            - cdrPANTONEPastelCoated # CorelDRAW 10 DRAW10VBA.HLP, no longer in CorelDRAW 11 DRAW11VBA.HLP
            - panpastc
          doc-ref: https://github.com/LibreOffice/libcdr/blob/b14f6a1f17652aa842b23c66236610aea5233aa6/src/lib/CDRColorPalettes.h#L2982
          doc: PANTONE Pastel Colors Coated - Corel 10
        22:
          id: pantone_pastel_uncoated_corel10
          -orig-id:
            - cdrPANTONEPastelUncoated # CorelDRAW 10 DRAW10VBA.HLP, no longer in CorelDRAW 11 DRAW11VBA.HLP
            - panpastu
          doc-ref: https://github.com/LibreOffice/libcdr/blob/b14f6a1f17652aa842b23c66236610aea5233aa6/src/lib/CDRColorPalettes.h#L3032
          doc: PANTONE Pastel Colors Uncoated - Corel 10
        23:
          id: hks
          -orig-id: HKS(r) Colors
        24:
          id: pantone_hex_uncoated_corel10
          -orig-id:
            - cdrPANTONEHexUncoated # CorelDRAW 10 DRAW10VBA.HLP, no longer in CorelDRAW 11 DRAW11VBA.HLP
            - panhexu
          doc: PANTONE Hexachrome Uncoated - Corel 10
        25:
          id: web_safe
          -orig-id:
            - WebSafe # file name
          doc: Web-safe Colors
        26:
          id: hks_k
          -orig-id:
            - HKS_K # file name
          doc-ref: https://github.com/LibreOffice/libcdr/blob/b14f6a1f17652aa842b23c66236610aea5233aa6/src/lib/CDRColorPalettes.h#L3960
        27:
          id: hks_n
          -orig-id:
            - HKS_N # file name
          doc-ref: https://github.com/LibreOffice/libcdr/blob/b14f6a1f17652aa842b23c66236610aea5233aa6/src/lib/CDRColorPalettes.h#L4002
        28:
          id: hks_z
          -orig-id:
            - HKS_Z # file name
          doc-ref: https://github.com/LibreOffice/libcdr/blob/b14f6a1f17652aa842b23c66236610aea5233aa6/src/lib/CDRColorPalettes.h#L4044
        29:
          id: hks_e
          -orig-id:
            - HKS_E # file name
          doc-ref: https://github.com/LibreOffice/libcdr/blob/b14f6a1f17652aa842b23c66236610aea5233aa6/src/lib/CDRColorPalettes.h#L4086
        30:
          id: pantone_metallic
          -orig-id:
            - panmetlc
          doc: PANTONE(r) metallic coated
        31:
          id: pantone_pastel_coated
          -orig-id:
            - panpasc
          doc: PANTONE(r) pastel coated
        32:
          id: pantone_pastel_uncoated
          -orig-id:
            - panpasu
          doc: PANTONE(r) pastel uncoated
        33:
          id: pantone_hex_coated
          -orig-id:
            - panhexac
          doc: PANTONE(r) hexachrome(r) coated
        34:
          id: pantone_hex_uncoated
          -orig-id:
            - PANTONE(r) hexachrome(r) uncoated
            - panhexau
        35:
          id: pantone_matte
          -orig-id:
            - pantonem
          doc: PANTONE(r) solid matte
        36:
          id: pantone_coated
          -orig-id:
            - pantonec
          doc: PANTONE(r) solid coated
        37:
          id: pantone_uncoated
          -orig-id:
            - pantoneu
          doc: PANTONE(r) solid uncoated
        38:
          id: pantone_process_coated_euro
          -orig-id:
            - paneuroc
          doc: PANTONE(r) process coated EURO
        39:
          id: pantone_solid2process_euro
          -orig-id:
            - pans2pec
          doc: PANTONE(r) solid to process EURO
        40:
          id: svg_named_colors
          -orig-id:
            - cdrSVGPalette
            - SVGColor # file name (SVGColor.xml)
          doc: SVG Colors
  draw_chunk_data:
    seq:
      - id: unknown1
        size: 8
      - id: len_body
        type: u4
      - id: body
        size: len_body
  thum_chunk_data:
    seq:
      - id: unknown1
        size: 8
      - id: len_body
        type: u4
      - id: body
        type: thum_body
        size: len_body
    types:
      thum_body:
        seq:
          - id: data_offset
            type: u4
          - id: width
            type: u4
          - id: height
            type: u4
          - id: unknown1
            size: 2
          - id: bpp
            type: u2
            valid:
              expr: bpp % 8 == 0
          - id: unknown2
            size: 4
          - id: len_data
            type: u4
            valid: len_line * height
          - id: unknown3
            size: 16
          - size: 0
            if: real_data_offset < 0
          - id: data
            size: len_data
            valid:
              expr: 'real_data_offset == data_offset'
        instances:
          real_data_offset:
            value: _io.pos
          unpadded_len_line:
            value: width * (bpp / 8)
          # Nearest multiple of 4
          len_line:
            value: >-
              unpadded_len_line & 3 == 0
                ? unpadded_len_line
                : unpadded_len_line + (4 - (unpadded_len_line & 3))
  csty_chunk_data:
    seq:
      - id: unknown
        size: 12
      - id: len_style
        type: u4
      - id: style
        type: str
        size: len_style
  retx_chunk_data:
    seq:
      - id: unknown
        size: 4
  poly_chunk_data:
    seq:
      # These values appear to be offsets; some relative to the beginning of `poly_chunk_data`,
      # others relative to the beginning of `body`.
      - id: offsets
        type: u4
        repeat: expr
        repeat-expr: 11
      - size: 0
        if: ofs_body < 0
      - id: body
        size: offsets[2] + 24
    instances:
      ofs_body:
        value: _io.pos
      bboxes:
        pos: ofs_body + offsets[0]
        type: points_list(2)
        repeat: until
        repeat-until: _.type != 1
      num_points:
        pos: ofs_body + offsets[8]
        type: u4
      points:
        pos: ofs_body + offsets[8] + 4
        type: points_list(num_points)
    types:
      point:
        seq:
          - id: x
            type: coord
          - id: y
            type: coord
      points_list:
        params:
          - id: num_points
            type: u4
        seq:
          - id: type
            type: u1
          - id: points
            type: point
            repeat: expr
            repeat-expr: num_points
            if: type == 1
  meta_chunk_data:
    seq:
      - id: unknown1
        size: 4
      - id: properties
        type: property
        repeat: until
        repeat-until: '_.name == ""'
      # TODO: Is this really part of the meta chunk?
      - id: unknown2
        size: 8
    types:
      property:
        seq:
          - id: name
            # property names are always four bytes, but we need to handle the empty string which
            # delimits the end of the list
            type: strz
            size: 4
          - id: len_body
            type: u4
          - id: body
            type:
              switch-on: name
              cases:
                '"vers"': version
                '"targ"': target_version
            size: len_body
      version:
        doc: |
          Version of CorelDRAW used to export the file, in order from major to minor.
          E.g., CorelDRAW 24.3.0.571 has `a` = 24, `b` = 3, `c` = 0, and `d` = 571
        seq:
          - id: a
            type: u2
          - id: b
            type: u2
          - id: c
            type: u2
          - id: d
            type: u2
      target_version:
        seq:
          - id: version
            type: u4

  rest_of_chunks:
    seq:
      - id: rest
        size-eos: true
  coord:
    seq:
      - id: raw
        type: s4
    instances:
      value:
        value: raw / 254000.0
