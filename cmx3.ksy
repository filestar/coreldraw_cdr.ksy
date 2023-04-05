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
    contents: CMX3
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
types:
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
        size: len_body
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
          - id: scanline_padding
            type: u2
          - id: bpp
            type: u2
            valid:
              expr: bpp % 8 == 0
          - id: unknown2
            size: 4
          - id: len_data
            type: u4
            valid: (width * (bpp / 8) + scanline_padding) * height
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
      - id: unknown
        # very unlikely to be correct in the general case, of course.
        size: 135
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
