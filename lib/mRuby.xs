#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "../ppport.h"

#include "mruby.h"
#include "mruby/array.h"
#include "mruby/class.h"
#include "mruby/compile.h"
#include "mruby/hash.h"
#include "mruby/khash.h"
#include "mruby/proc.h"
#include "mruby/string.h"
#include "mruby/variable.h"

KHASH_DECLARE(ht, mrb_value, mrb_value, 1);
/* KHASH_DEFINE (ht, mrb_value, mrb_value, 1, mrb_hash_ht_hash_func, mrb_hash_ht_hash_equal); */

static
SV * mrb_value2sv(pTHX_ mrb_state *mrb, const mrb_value v) {
    switch (mrb_type(v)) {
    case MRB_TT_FALSE:
    case MRB_TT_UNDEF:
        return &PL_sv_undef;
    case MRB_TT_TRUE:
        return newSViv(1);
    case MRB_TT_FIXNUM:
        return newSViv(mrb_fixnum(v));
    case MRB_TT_FLOAT:
        return newSVnv(mrb_float(v));
    case MRB_TT_STRING:
        return newSVpv((char*)RSTRING_PTR(v), (STRLEN)RSTRING_LEN(v));
    case MRB_TT_SYMBOL: {
        mrb_int len;
        const char *name = mrb_sym2name_len(mrb, mrb_symbol(v), &len);
        return newSVpv((char*)name, (STRLEN)len);
    }
    case MRB_TT_HASH: {
        const mrb_value  keys = mrb_hash_keys(mrb, v);
        const mrb_value *ptr  = RARRAY_PTR(keys);
        const int        len  = RARRAY_LEN(keys);

        HV * ret = newHV();

        int i;
        for (i=0; i<len; i++) {
            const mrb_value kk = ptr[i];
            const mrb_value vv = mrb_hash_get(mrb, v, kk);

            STRLEN key_len;
            const char *key = SvPV(mrb_value2sv(aTHX_ mrb, kk), key_len);
            hv_store(ret, key, key_len, mrb_value2sv(aTHX_ mrb, vv), 0);
        }

        return newRV_noinc((SV*)ret);
    }
    case MRB_TT_ARRAY: {
        const mrb_value *ptr = RARRAY_PTR(v);
        const int        len = RARRAY_LEN(v);

        AV * ret = newAV();

        int i;
        for (i=0; i<len; i++) {
            av_push(ret, mrb_value2sv(aTHX_ mrb, ptr[i]));
        }

        return newRV_noinc((SV*)ret);
    }
    default:
        croak("This type of ruby value is not supported yet: %d", mrb_type(v));
    }
    abort();
}

MODULE = mRuby      PACKAGE = mRuby

MODULE = mRuby      PACKAGE = mRuby::State

void
new(const char *klass)
    PPCODE:
        const mrb_state* mrb = mrb_open();
        XPUSHs(sv_bless(newRV_noinc(sv_2mortal(newSViv(PTR2IV(mrb)))), gv_stashpv(klass, TRUE)));
        XSRETURN(1);

void
parse_string(mrb_state *mrb, const char *src)
    PPCODE:
        const struct mrb_parser_state* st = mrb_parse_string(mrb, src, NULL);
        XPUSHs(sv_bless(newRV_noinc(sv_2mortal(newSViv(PTR2IV(st)))), gv_stashpv("mRuby::ParserState", TRUE)));
        XSRETURN(1);

void
generate_code(mrb_state *mrb, struct mrb_parser_state* st)
    PPCODE:
        const struct RProc * proc = mrb_generate_code(mrb, st);
        XPUSHs(sv_bless(newRV_noinc(sv_2mortal(newSViv(PTR2IV(proc)))), gv_stashpv("mRuby::RProc", TRUE)));
        XSRETURN(1);

void
run(mrb_state *mrb, struct RProc* proc, SV *val=&PL_sv_undef)
    PPCODE:
        const mrb_value ret = mrb_run(mrb, proc, mrb_nil_value());
        mXPUSHs(mrb_value2sv(aTHX_ mrb, ret));
        XSRETURN(1);

MODULE = mRuby      PACKAGE = mRuby::ParserState

void
pool_close(struct mrb_parser_state* st)
    PPCODE:
        mrb_pool_close(st->pool);
        XSRETURN_UNDEF;

MODULE = mRuby      PACKAGE = mRuby::RProc

