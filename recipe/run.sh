#!/bin/bash
# Apache 2.0

# This script prepares data and trains + decodes an ASR system.

# initialization PATH
. ./path.sh  || die "path.sh expected";
# initialization commands
. ./cmd.sh
. ./utils/parse_options.sh
set -e -o pipefail

###############################################################
#                   Configuring the ASR pipeline
###############################################################
stage=0    # from which stage should this script start
corpus=./corpus  # corpus containing speech,transcripts,pronunciation dictionary
nj=4        # number of parallel jobs to run during training
dev_nj=4    # number of parallel jobs to run during decoding
# the above two parameters are typically set to the number of cores on your machine
###############################################################

# Stage 1: Prepares the train/dev data. Prepares the dictionary and the
# language model.
if [ $stage -le 1 ]; then
  echo "Preparing data and training language models"
  local/prepare_data.sh $corpus
  local/prepare_dict.sh $corpus
  utils/prepare_lang.sh data_words/local/dict "<UNK>" data_words/local/lang data_words/lang
  utils/prepare_lang.sh data_phones/local/dict "<UNK>" data_phones/local/lang data_phones/lang
  local/prepare_lm.sh
fi

# Stage 2: MFCC feature extraction + mean-variance normalization
if [ $stage -le 2 ]; then
  for x in train dev; do
      steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" data_words/$x exp/make_mfcc_words/$x mfcc_words
      steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" data_phones/$x exp/make_mfcc_phones/$x mfcc_phones
      echo "_-------------------------------------------------"
      steps/compute_cmvn_stats.sh data_words/$x exp/make_mfcc_words/$x mfcc_words
      steps/compute_cmvn_stats.sh data_phones/$x exp/make_mfcc_phones/$x mfcc_phones
  done
fi

# Stage 3: Training word-based acoustic models
if [ $stage -le 3 ]; then
  ### Words
  echo "Word-based training"
  steps/train_mono.sh --nj $nj --cmd "$train_cmd" data_words/train data_words/lang exp/words
  echo "Word-based training complete"
fi

# Stage 4: Training monophone acoustic models
if [ $stage -le 4 ]; then
  ### Monophone
  echo "Monophone training"
  steps/train_mono.sh --nj $nj --cmd "$train_cmd" data_phones/train data_phones/lang exp/mono
  echo "Monophone training complete"
fi

# Stage 5: Training triphone acoustic models
if [ $stage -le 5 ]; then
  ### Triphone
  echo "Triphone training"
  steps/align_si.sh --nj $nj --cmd "$train_cmd" \
      data_phones/train data_phones/lang exp/mono exp/mono_ali
  steps/train_deltas.sh --boost-silence 1.25  --cmd "$train_cmd"  \
      2500 15000 data_phones/train data_phones/lang exp/mono_ali exp/tri1
  echo "Triphone training complete"
fi

# Stage 6: Decoding test utterances in data/dev
if [ $stage -le 6 ]; then
  (
  echo "Decoding the dev set using word-based models."
  utils/mkgraph.sh data_words/lang_test exp/words exp/words/graph

  steps/decode.sh --config conf/decode.config --nj $dev_nj --cmd "$decode_cmd" \
    exp/words/graph data_words/dev exp/words/decode_dev
  echo "Word-based decoding done."

  echo "Decoding the dev set using monophone models."
  utils/mkgraph.sh data_phones/lang_test exp/mono exp/mono/graph

  steps/decode.sh --config conf/decode.config --nj $dev_nj --cmd "$decode_cmd" \
    exp/mono/graph data_phones/dev exp/mono/decode_dev
  echo "Monophone decoding done."

  echo "Decoding the dev set using triphone models."
  utils/mkgraph.sh data_phones/lang_test exp/tri1 exp/tri1/graph

  steps/decode.sh --config conf/decode.config --nj $dev_nj --cmd "$decode_cmd" \
    exp/tri1/graph data_phones/dev exp/tri1/decode_dev
  echo "Triphone decoding done."
  ) &
fi

wait;
# Computing the WERs on the development set
for x in exp/*/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done
