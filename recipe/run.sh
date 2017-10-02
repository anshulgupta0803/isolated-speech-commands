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
  utils/prepare_lang.sh data/local/dict "<UNK>" data/local/lang data/lang
  local/prepare_lm.sh
fi

# Stage 2: MFCC feature extraction + mean-variance normalization
if [ $stage -le 2 ]; then
  for x in train dev; do
      steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" data/$x exp/make_mfcc/$x mfcc
      steps/compute_cmvn_stats.sh data/$x exp/make_mfcc/$x mfcc
  done
fi

# Stage 3: Training monophone acoustic models
if [ $stage -le 3 ]; then
  ### Monophone
  echo "Monophone training"
  steps/train_mono.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/mono
  echo "Monophone training complete"
fi

if [ $stage -le 4 ]; then
  ### Triphone
  echo "Triphone training"
  steps/align_si.sh --nj $nj --cmd "$train_cmd" \
      data/train data/lang exp/mono exp/mono_ali
  steps/train_deltas.sh --boost-silence 1.25  --cmd "$train_cmd"  \
      3200 30000 data/train data/lang exp/mono_ali exp/tri1
  echo "Triphone training complete"
fi

# Stage 5: Decoding test utterances in data/dev
if [ $stage -le 5 ]; then
  (
  echo "Decoding the dev set using monophone models."
  utils/mkgraph.sh data/lang_test exp/mono exp/mono/graph

  steps/decode.sh --config conf/decode.config --nj $dev_nj --cmd "$decode_cmd" \
    exp/mono/graph data/dev exp/mono/decode_dev
  echo "Monophone decoding done."

  echo "Decoding the dev set using triphone models."
  utils/mkgraph.sh data/lang_test exp/tri1 exp/tri1/graph

  steps/decode.sh --config conf/decode.config --nj $dev_nj --cmd "$decode_cmd" \
    exp/tri1/graph data/dev exp/tri1/decode_dev
  echo "Triphone decoding done."
  ) &
fi

wait;
# Computing the WERs on the development set
for x in exp/*/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done
