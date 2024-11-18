/*
 * bbc2png
 *
 * This program converts a dump of screen memory from a BBC micro into
 * a PNG image of the screen concerned.  For mode 2, the flashing
 * colours are not converted to flashing colours within the PNG file
 * but instead to the corresponding non-flashing colour.
 */

#include <ctype.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <png.h>

static const png_color pal_physical[8] = {
    {   0,   0,   0 }, // black.
    { 255,   0,   0 }, // red
    {   0, 255,   0 }, // green
    { 255, 255,   0 }, // yellow
    {   0,   0, 255 }, // blue
    { 255,   0, 255 }, // magenta
    {   0, 255, 255 }, // cyan
    { 255, 255, 255 }, // white
};

typedef png_bytep (*decode_func)(png_byte byte, png_bytep pixp);

static png_bytep decode_tc(png_byte byte, png_bytep pixp)
{
    *pixp++ = (byte & 0x80) >> 7;
    *pixp++ = (byte & 0x40) >> 6;
    *pixp++ = (byte & 0x20) >> 5;
    *pixp++ = (byte & 0x10) >> 4;
    *pixp++ = (byte & 0x08) >> 3;
    *pixp++ = (byte & 0x04) >> 2;
    *pixp++ = (byte & 0x02) >> 1;
    *pixp++ = (byte & 0x01);
    return pixp;
}

static png_bytep decode_fc(png_byte byte, png_bytep pixp)
{
    *pixp++ = ((byte & 0x80) >> 6) | ((byte & 0x08) >> 3);
    *pixp++ = ((byte & 0x40) >> 5) | ((byte & 0x04) >> 2);
    *pixp++ = ((byte & 0x20) >> 4) | ((byte & 0x02) >> 1);
    *pixp++ = ((byte & 0x10) >> 3) | (byte & 0x01);
    return pixp;
}

static png_bytep decode_sc(png_byte byte, png_bytep pixp)
{
    *pixp++ = ((byte & 0x20) >> 3) | ((byte & 0x08) >> 2) | ((byte & 0x02) >> 1);
    *pixp++ = ((byte & 0x10) >> 2) | ((byte & 0x04) >> 1) | (byte & 0x01);
    return pixp;
}

typedef struct {
    decode_func decoder;
    unsigned width;
    unsigned stride;
    png_byte char_rows;
    png_byte gaps;
    png_byte pal_size;
    png_byte palette[8];
} bbc_mode;

static const bbc_mode modes[7] = {
    { decode_tc, 640, 0x280, 32, 0, 2, { 0, 7, 0, 7, 0, 7, 0, 7 } },
    { decode_fc, 320, 0x280, 32, 0, 4, { 0, 1, 3, 7, 0, 1, 3, 7 } },
    { decode_sc, 160, 0x280, 32, 0, 8, { 0, 1, 2, 3, 4, 5, 6, 7 } },
    { decode_tc, 640, 0x280, 25, 2, 2, { 0, 7, 0, 7, 0, 7, 0, 7 } },
    { decode_tc, 320, 0x140, 32, 0, 2, { 0, 7, 0, 7, 0, 7, 0, 7 } },
    { decode_fc, 160, 0x140, 32, 0, 4, { 0, 1, 3, 7, 0, 1, 3, 7 } },
    { decode_tc, 320, 0x140, 25, 2, 2, { 0, 7, 0, 7, 0, 7, 0, 7 } }
};

static void transform(const bbc_mode *modep, const png_byte *pal_log, png_bytep bbc_scr, png_structp png_ptr, png_infop info_ptr)
{
    unsigned height = modep->char_rows * (8 + modep->gaps);
    size_t row_bytes = height * sizeof(png_bytep);
    size_t pix_bytes = modep->width * height;
    png_bytep *rows = malloc(row_bytes + pix_bytes);
    if (rows) {
        png_bytep pixels = (png_bytep)rows + row_bytes;
        png_bytep pixp = pixels;
        for (unsigned char_row = 0; char_row < modep->char_rows; ++char_row) {
            for (unsigned pixl_row = 0; pixl_row < 8; ++pixl_row) {
                unsigned offs = char_row * modep->stride + pixl_row;;
                png_bytep bbcp = bbc_scr + offs;
                png_bytep next = bbcp + modep->stride;
                while (bbcp < next) {
                    pixp = modep->decoder(*bbcp, pixp);
                    bbcp += 8;
                }
            }
            if (modep->gaps) {
                size_t bytes = modep->width * 2;
                memset(pixp, 0, bytes);
                pixp += bytes;
            }
        }
        pixp = pixels;
        for (int row = 0; row < height; ++row) {
            rows[row] = pixp;
            pixp += modep->width;
        }
        png_set_IHDR(png_ptr, info_ptr, modep->width, height, 8, PNG_COLOR_TYPE_PALETTE, PNG_INTERLACE_NONE, PNG_COMPRESSION_TYPE_DEFAULT, PNG_FILTER_TYPE_DEFAULT);
        png_color palette[8];
        for (int pal_ent = 0; pal_ent < modep->pal_size; ++pal_ent)
            palette[pal_ent] = pal_physical[pal_log[pal_ent]];
        png_set_PLTE(png_ptr, info_ptr, palette, modep->pal_size);
        png_set_rows(png_ptr, info_ptr, rows);
        png_write_png(png_ptr, info_ptr, PNG_TRANSFORM_IDENTITY, NULL);
        free(rows);
    }
}

static int bbc2png(const bbc_mode *modep, const png_byte *pal_log, const char *bbc_fn, const char *png_fn)
{
    int status = 0;
    FILE *bbc_fp = fopen(bbc_fn, "rb");
    if (bbc_fp) {
        fseek(bbc_fp, 0, SEEK_END);
        long size = ftell(bbc_fp);
        if (size > 0) {
            png_bytep bbc_scr = malloc(size);
            if (bbc_scr) {
                fseek(bbc_fp, 0, SEEK_SET);
                if (fread(bbc_scr, size, 1, bbc_fp) == 1) {
                    FILE *png_fp = fopen(png_fn, "wb");
                    if (png_fp) {
                        png_structp png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
                        if (png_ptr) {
                            png_init_io(png_ptr, png_fp);
                            png_infop info_ptr = png_create_info_struct(png_ptr);
                            if (info_ptr) {
                                transform(modep, pal_log, bbc_scr, png_ptr, info_ptr);
                                png_destroy_write_struct(&png_ptr, &info_ptr);
                            }
                            else {
                                fprintf(stderr, "bb2png: out of memory writing %s\n", png_fn);
                                png_destroy_write_struct(&png_ptr, (png_infopp)NULL);
                                status = 1;
                            }
                        }
                        else {
                            fprintf(stderr, "bb2png: out of memory writing %s\n", png_fn);
                            status = 1;
                        }
                        fclose(png_fp);
                    }
                    else {
                        fprintf(stderr, "bb2png: unable to open %s for writing: %s\n", png_fn, strerror(errno));
                        status = 1;
                    }
                }
                else {
                    fprintf(stderr, "bb2png: read error on %s: %s\n", bbc_fn, strerror(errno));
                    status = 1;
                }
            }
            else {
                fprintf(stderr, "bb2png: out of memory reading %s\n", bbc_fn);
                status = 1;
            }
        }
        else {
            fprintf(stderr, "bb2png: input file %s is empty\n", bbc_fn);
            status = 1;
        }
        fclose(bbc_fp);
    }
    else {
        fprintf(stderr, "bb2png: unable to open %s for reading: %s\n", bbc_fn, strerror(errno));
        status = 1;
    }
    return status;
}

static int without_inf(int mode, const char *bbc_fn, const char *png_fn)
{
    if (mode >= 0) {
        const bbc_mode *modep = modes + mode;
        return bbc2png(modep, modep->palette, bbc_fn, png_fn);
    }
    else {
        fprintf(stderr, "bbc2png: for %s, no mode from .inf or default mode set\n", bbc_fn);
        return 1;
    }
}

static int with_inf(int mode, FILE *inf_fp, const char *bbc_fn, const char *png_fn)
{
    unsigned load_addr, exec_addr;
    int items = fscanf(inf_fp, "%*s %x %x", &load_addr, &exec_addr);
    fclose(inf_fp);
    if (items == 2) {
        mode = (exec_addr >> 12) & 0x0f;
        if (mode <= 6) {
            png_byte pal_log[8];
            pal_log[0] = exec_addr & 0x07;
            pal_log[1] = (exec_addr >> 3) & 0x07;
            pal_log[2] = (exec_addr >> 6) & 0x07;
            pal_log[3] = (exec_addr >> 9) & 0x07;
            pal_log[4] = load_addr & 0x07;
            pal_log[5] = (load_addr >> 3) & 0x07;
            pal_log[6] = (load_addr >> 6) & 0x07;
            pal_log[7] = (load_addr >> 9) & 0x07;
            return bbc2png(modes + mode, pal_log, bbc_fn, png_fn);
        }
        else {
            fprintf(stderr, "bbc2png: mode %d is not supported\n", mode);
            return 1;
        }
    }
    else {
        fprintf(stderr, "bbc2png: unable to read load/exec for %s\nbbc2png: using default mode and palette\n", bbc_fn);
        return without_inf(mode, bbc_fn, png_fn);
    }
}

int main(int argc, char **argv)
{
    int mode = -1;
    int status = 0;
    char *inf_fn = NULL;
    while (argc >= 3) {
        const char *arg = argv[1];
        if (arg[0] == '-' && arg[1] == 'm') {
            if (isdigit(arg[2])) {
                mode = atoi(arg+2);
                argv += 1;
                argc -= 1;
            }
            else {
                mode = atoi(argv[2]);
                argv += 2;
                argc -= 2;
            }
            if (mode < 0 || mode > 6) {
                fprintf(stderr, "bbc2img: invalid mode %s\n", argv[1]);
                return 1;
            }
        }
        else {
            if (asprintf(&inf_fn, "%s.inf", arg) > 0) {
                FILE *inf_fp = fopen(inf_fn, "r");
                if (inf_fp)
                    status += with_inf(mode, inf_fp, arg, argv[2]);
                else
                    status += without_inf(mode, arg, argv[2]);
            }
            else {
                fputs("bbc2png: out of memory\n", stderr);
                return 1;
            }
            argv += 2;
            argc -= 2;
        }
    }
    if (argc != 1) {
        fputs("Usage: bbc2img [ -m mode ] <bbc-img> <png-omg> [...]\n", stderr);
        return 1;
    }
}
