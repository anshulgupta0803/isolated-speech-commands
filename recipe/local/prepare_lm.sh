#!/bin/bash
# Apache 2.0

set -e -o pipefail

. ./path.sh || die "path.sh expected";

local/train_lms_srilm.sh --train-text data_words/train/text data_words/ data_words/srilm
local/train_lms_srilm.sh --train-text data_phones/train/text data_phones/ data_phones/srilm

nl -nrz -w10  corpus/LM/train.txt | utils/shuffle_list.pl > data_words/local/external_text
nl -nrz -w10  corpus/LM/train.txt | utils/shuffle_list.pl > data_phones/local/external_text

local/train_lms_srilm.sh --train-text data_words/local/external_text data_words/ data_words/srilm_external
local/train_lms_srilm.sh --train-text data_phones/local/external_text data_phones/ data_phones/srilm_external

[ -d data_words/lang_test/ ] && rm -rf data_words/lang_test
[ -d data_phones/lang_test/ ] && rm -rf data_phones/lang_test

cp -R data_words/lang data_words/lang_test
cp -R data_phones/lang data_phones/lang_test

lm_words=data_words/srilm/lm.gz
lm_phones=data_phones/srilm/lm.gz

local/arpa2G.sh $lm_words data_words/lang_test data_words/lang_test
local/arpa2G.sh $lm_phones data_phones/lang_test data_phones/lang_test

exit 0;
