# 画像の輪郭線抽出に関する最新論文・技術調査メモ

最終更新: 2026-05-01  
対象: 画像の輪郭線抽出、エッジ検出、contour detection、boundary detection、crisp edge detection、perceptual edge detection、line extraction

---

## 1. 調査対象の範囲

本メモでは、画像から輪郭線・境界線・エッジを抽出する研究を広く扱う。

対象に含めたキーワードは以下。

- edge detection
- contour detection
- boundary detection
- perceptual edge detection
- crisp edge detection
- one-pixel edge detection
- multi-granularity edge detection
- line extraction
- sketch / lineart extraction に近い応用
- transformer edge detector
- Mamba edge detector
- diffusion edge detector
- SAM / foundation model を利用した境界抽出

---

## 2. 現在の大きなトレンド

### 2.1 crisp edge / one-pixel edge への移行

従来の深層学習ベースのエッジ検出は、出力線が太くなりやすく、NMS、thinning、後処理に依存しがちだった。

2025〜2026年の研究では、後処理なしで細い線を出す **crisp edge detection** が重要テーマになっている。

代表例:

- MEMO: Human-like Crisp Edge Detection Using Masked Edge Prediction
- MatchED: Crisp Edge Detection Using End-to-End, Matching-based Supervision
- EasyControlEdge: Foundation-model fine-tuning for edge detection

---

### 2.2 Foundation Model / Diffusion / SAM の活用

近年は、エッジ検出専用モデルをゼロから作るだけでなく、以下のような大規模モデルの知識を使う方向が増えている。

- Diffusion model
- SAM / Segment Anything Model
- 画像生成系foundation model
- 大規模事前学習済みencoder

代表例:

- EasyControlEdge
- TRACE: Your Diffusion Model is Secretly an Instance Edge Detector
- Taming SAM for Uncertainty-Aligned Multi-Granularity Edge Detection

---

### 2.3 Transformer / Mamba による長距離依存の活用

エッジ検出では、局所的な勾配だけでなく、物体全体の形状や文脈も重要になる。
そのため、TransformerやMambaを使ってglobal contextを扱う研究が増えている。

代表例:

- EDTER: Edge Detection with Transformers
- EDMB: Edge Detector with Mamba
- EFED: Efficient Transformer-based Edge Detector

---

### 2.4 軽量・高速・省電力化

モバイル、リアルタイム処理、組み込み用途では、軽量性が重要になる。

代表例:

- PiDiNet
- PEdger++
- MS2Edge
- EFED
- CTFN
- LDC

---

### 2.5 ラベル不確実性・多粒度エッジ

BSDS500のようなデータセットでは、複数アノテータが異なる粒度でエッジを付ける。
この曖昧さを単なるノイズとして扱うのではなく、不確実性として学習に取り込む研究が増えている。

代表例:

- UAED
- Taming SAM for Uncertainty-Aligned Multi-Granularity Edge Detection
- EDMB

---

## 3. 重要論文リスト: 2024〜2026中心

| 年 | 論文・手法 | 概要 | 備考 |
|---:|---|---|---|
| 2026 | MEMO: Human-like Crisp Edge Detection Using Masked Edge Prediction | Masked Edge Predictionとprogressive predictionにより、後処理なしのcrisp edgeを狙う。 | CVPR 2026採択とされる最新系。 |
| 2026 | MatchED: Crisp Edge Detection Using End-to-End, Matching-based Supervision | 予測エッジとGTエッジを1対1マッチングする教師信号で、太い線を抑える。 | 既存モデルに追加しやすいplug-and-play方向。 |
| 2026 | EasyControlEdge: A Foundation-Model Fine-Tuning for Edge Detection | 画像生成系foundation modelをエッジ検出にfine-tune。 | BSDS500、NYUDv2、BIPED、CubiCasaで評価。 |
| 2026 | Adaptive Multi-stage Non-edge Pruning for Edge Detection | 非エッジ領域を段階的にpruningし、Transformer系の計算コストを削減。 | 高解像度・効率性重視。 |
| 2026 | Rule-Based Spatial Mixture-of-Experts U-Net | sMoEとTSK fuzzy headで説明可能性を持つエッジ検出。 | 精度最優先というより説明性重視。 |
| 2026 | Prompt-Guided Multi-Task Learning for Petrographic Thin-section Images | 岩石薄片画像の粒界抽出と岩相セグメンテーションを扱う。 | 地質・岩石画像向け。 |
| 2026 | Contour Refinement using Discrete Diffusion in Low Data Regime | segmentation maskを条件に、sparse contourを離散拡散で補正。 | low-data contour refinement。 |
| 2025 | MS2Edge: Towards Energy-Efficient and Crisp Edge Detection | Spiking Neural Network系。crisp edgeと省電力を重視。 | BSDS500、NYUDv2、BIPEDなど。 |
| 2025 | EDMB: Edge Detector with Mamba | Mambaをglobal-local構成に用いる。 | BSDS500で高いODSを報告。 |
| 2025 | Taming SAM for Uncertainty-Aligned Multi-Granularity Edge Detection | SAMを使って不確実性に沿ったmulti-granularity edgeを生成。 | AAAI 2025。 |
| 2025 | TRACE: Your Diffusion Model is Secretly an Instance Edge Detector | Diffusion modelのself-attentionからinstance boundaryを抽出・蒸留。 | instance-level edgeに近い。 |
| 2025 | SWBCE: Symmetrization Weighted Binary Cross-Entropy | エッジ検出のクラス不均衡と損失設計を扱う。 | loss設計系。 |
| 2025 | Pixel-Wise Feature Selection for Perceptual Edge Detection | 画素単位で有効な特徴を選択する。 | perceptual edge detection。 |
| 2025 | High-Precision Edge Detection via Task-Adaptive Texture Handling / SDPED | textureとedgeの区別、評価整合性を重視。 | 高精度edge detection。 |
| 2025 | PEdger++ | cross-architecture collaborative learningで軽量・高精度を狙う。 | 効率性重視。 |
| 2025 | CAM-EDIT | Channel Attentionと統計的独立性検定でノイズ・非顕著ディテールを抑制。 | BSDS500、NYUDv2。 |
| 2025 | MTS-DR-Net | Multi-scale Tensorial SummationとDimensional Reductionを利用。 | BSDS500、BIPEDv2。 |
| 2025 | Learning to utilize image second-order derivative information | 二階微分情報を深層エッジ検出に組み込む。 | HED、RCF、DexiNedなどを背景にする。 |
| 2025 | Enhanced edge detection via Dual-branch attention fusion | dual-branch attention fusionで物体輪郭検出を改善。 | deep edge detection。 |
| 2025 | CTFN: Compact Twice Fusion Network | Dynamic Focal Lossと軽量fusionで高効率化。 | BSDS500、NYUDv2、BIPEDv2。 |
| 2024/2026 | NBED: A New Baseline for Edge Detection | encoder-decoderを再評価し、高品質特徴が重要と主張。 | BSDS500 ODS 0.838を報告。 |
| 2024 | RankED | ranking-based lossでクラス不均衡とラベル不確実性を扱う。 | edge detection全般。 |
| 2024/2025 | msmsfnet | SARなどImageNet事前学習が効きにくい領域でscratch training可能。 | SAR edge detection。 |
| 2024 | EFED: Efficient Transformer-based Edge Detector | EDTER級の精度を維持しつつスループット改善。 | BSDS500で評価。 |
| 2024 | Defective Edge Detection Using Cascaded Ensemble Canny Operator | Canny系とensemble/backbone/attentionの組み合わせ。 | 伝統手法と深層手法の中間的方向。 |

---

## 4. 2023以前だが重要な基礎論文

| 年 | 論文・手法 | 重要性 |
|---:|---|---|
| 1986 | Canny Edge Detector | 現在でも比較対象・後処理・教師信号生成に使われる古典。 |
| 2015 | HED: Holistically-Nested Edge Detection | 深層学習エッジ検出の転換点。FCNとdeep supervisionを使用。 |
| 2021 | PiDiNet | Pixel Difference Convolutionで伝統的な差分演算をCNNに組み込む。軽量・高速。 |
| 2021/2023 | DexiNed / BIPED | scratch training可能なDense Extreme Inception Network。シャープな線が特徴。 |
| 2022 | EDTER | Transformer系エッジ検出の代表。global contextとlocal cueを二段階で扱う。 |
| 2023 | UAED | 複数アノテータの不一致を不確実性として学習に利用。 |
| 2023 | CHRNet | cascaded high-resolution networkで複雑シーンのエッジを改善。 |

---

## 5. データセット・ベンチマーク

| データセット | 内容・用途 |
|---|---|
| BSDS500 / BSDS300 | 自然画像の代表的ベンチマーク。複数人アノテーション付き。ODS/OIS/APで比較される。 |
| NYUDv2 | RGB-D画像の境界検出で頻出。深度情報も使える。 |
| BIPED / BIPEDv2 | Barcelona Images for Perceptual Edge Detection。高解像度の屋外画像と専門家アノテーション。 |
| Multicue | boundary / edge系で使われる比較データセット。 |
| CubiCasa | フロアプランなど実応用寄りのエッジ・境界抽出。 |
| 医用画像 CT/MRI系 | 臓器境界・病変境界の局在精度を評価。Boundary F-measureやHausdorff distanceが重要。 |
| SAR / 衛星画像系 | ImageNet事前学習が効きにくい場合があり、専用モデルやscratch trainingが検討される。 |

---

## 6. 評価指標

| 指標 | 意味 |
|---|---|
| ODS | dataset全体で1つの閾値を選んだF-score。論文比較で最もよく出る。 |
| OIS | 画像ごとに最適閾値を選んだF-score。ODSより高くなりやすい。 |
| AP | precision-recall曲線下面積。閾値全体の性能を見る。 |
| AC / Average Crispness | 線の細さ・crispさを測る指標。MatchEDなどで重視。 |
| CEval | crispnessを重視する評価設定。 |
| Boundary F-measure | セグメンテーション境界や医用画像で重要。 |
| Hausdorff distance | 境界位置のズレを測る。医用画像などで重要。 |

---

## 7. 参考画像・出力例が見られる技術

### 7.1 DexiNed

参考画像あり。

主な場所:

- GitHub: https://github.com/xavysp/DexiNed
- Hugging Face / OpenCV系デモ: `opencv/edge_detection_dexined`

特徴:

- 線が比較的シャープ。
- Cannyよりも意味的な輪郭を拾いやすい。
- 線画抽出やイラスト寄りの用途でも試しやすい。

---

### 7.2 PiDiNet

参考画像あり。

主な場所:

- ICCV 2021 paper / project page
- HED、RCF、BDCNなどとの比較図

特徴:

- 軽量・高速。
- Pixel Difference Convolutionにより、勾配的な情報をCNNに入れている。
- モバイル・リアルタイム用途で候補になる。

---

### 7.3 EDTER

参考画像あり。

主な場所:

- 論文PDF
- 紹介ページ

特徴:

- Transformer系。
- 物体境界を文脈込みで捉える傾向。
- HEDなどよりglobal contextを利用しやすい。

---

### 7.4 EFED

参考画像あり。

主な場所:

- 論文PDFの定性的結果図

特徴:

- Efficient Transformer-based Edge Detector。
- EDTER系の高精度をより効率的に実現する方向。

---

### 7.5 Taming SAM

参考画像あり。

主な場所:

- arXiv HTML / 論文図

特徴:

- multi-granularity edgeの可視化が参考になる。
- 粗い物体輪郭から細かい境界まで、粒度を変えた出力を見るのに向く。

---

### 7.6 MEMO

参考画像あり。

主な場所:

- arXiv
- ResearchGate等のプレビュー

特徴:

- 後処理なしのcrisp edgeを重視。
- 太い線を避け、人間注釈に近い細い輪郭を狙う。

---

### 7.7 MatchED

参考画像ありと考えられる。

主な場所:

- arXiv論文内の定性的比較図

特徴:

- matching-based supervisionで、太い線や重複線を抑える。
- 既存モデルの出力をよりcrispにする方向。

---

### 7.8 Canny / Sobel / LoG / Roberts

参考画像は非常に多い。

特徴:

- 古典手法。
- 勾配・局所変化に敏感。
- 意味的な物体輪郭ではなく、テクスチャやノイズも拾いやすい。
- 深層学習系との差を見る比較対象として有用。

---

## 8. 用途別おすすめ候補

### 8.1 最新研究を追う場合

優先して読むべき候補:

1. MEMO
2. MatchED
3. EasyControlEdge
4. EDMB
5. Taming SAM
6. TRACE

理由:

- 2025〜2026年の主要トレンドであるcrisp edge、foundation model、multi-granularity、不確実性、Mamba/Diffusion/SAMをカバーできる。

---

### 8.2 実装して比較する場合

候補:

1. Canny
2. Sobel
3. PiDiNet
4. DexiNed
5. EDTER
6. UAED
7. NBED

理由:

- 古典手法と深層学習手法の差が分かりやすい。
- DexiNedやPiDiNetは比較的試しやすい。
- EDTERはTransformer系の代表として比較価値が高い。

---

### 8.3 漫画・イラスト・線画化に近い用途

候補:

1. DexiNed
2. PiDiNet
3. Canny / HED / RCF系
4. EasyControlEdge
5. MEMO
6. MatchED
7. SAM + boundary extraction
8. ControlNet系のCanny / Lineartプリプロセッサ

注意:

- 論文上のedge detectionは、自然画像・医用画像・リモートセンシングが中心。
- 漫画線画化そのものとは目的が少し異なる。
- ただし、crisp edge、perceptual edge、foundation model edgeは線画抽出用途に近い。

---

### 8.4 医用画像・産業画像

候補:

- organ boundary edge detection系
- contour refinement using diffusion
- boundary-aware segmentation
- Canny + deep learning hybrid
- SAM-based boundary refinement

重視すべき指標:

- Boundary F-measure
- Hausdorff distance
- Dice / IoUとの連携
- 境界位置のズレ

---

### 8.5 軽量・リアルタイム・省電力

候補:

1. PiDiNet
2. LDC
3. EFED
4. PEdger++
5. MS2Edge
6. CTFN

---

## 9. 暫定ランキング

一般画像の輪郭線抽出を想定した有力度ランキング。

| 順位 | 手法 | 有力度 | 理由 |
|---:|---|---:|---|
| 1 | MEMO | 9.2/10 | 後処理なしcrisp edgeを強く意識した最新研究。 |
| 2 | MatchED | 9.1/10 | matching-based supervisionで線の太さを抑える。既存モデルにも追加しやすい。 |
| 3 | EasyControlEdge | 8.8/10 | foundation model fine-tuningで少数データ・crispnessに強い方向。 |
| 4 | EDMB | 8.5/10 | Mamba + global-local + multi-granularity。 |
| 5 | Taming SAM / UAED系 | 8.4/10 | ラベル不確実性と多粒度エッジを扱う。 |
| 6 | MS2Edge | 8.2/10 | 省電力・SNN・crisp edgeという独自性。 |
| 7 | EDTER | 8.0/10 | Transformer系エッジ検出の代表。 |
| 8 | DexiNed | 7.8/10 | 実装・デモ・線のシャープさで実用性が高い。 |
| 9 | PiDiNet | 7.6/10 | 軽量・高速な実用候補。 |
| 10 | NBED | 7.5/10 | encoder-decoder再評価として堅実。 |

---

## 10. 主要リンク集

### DexiNed

- GitHub: https://github.com/xavysp/DexiNed
- BIPED / MBIPED: https://xavysp.github.io/MBIPED/
- Hugging Face: https://huggingface.co/opencv/edge_detection_dexined

### PiDiNet

- ICCV 2021 paper: https://openaccess.thecvf.com/content/ICCV2021/html/Su_Pixel_Difference_Networks_for_Efficient_Edge_Detection_ICCV_2021_paper.html

### EDTER

- arXiv: https://arxiv.org/abs/2203.08566

### HED

- arXiv: https://arxiv.org/abs/1504.06375

### UAED

- arXiv: https://arxiv.org/abs/2303.11828

### EasyControlEdge

- arXiv: https://arxiv.org/abs/2602.16238

### MatchED

- arXiv: https://arxiv.org/abs/2602.20689

### MEMO

- arXiv: https://arxiv.org/abs/2603.20782

### EDMB

- arXiv: https://arxiv.org/abs/2501.04846

### Taming SAM

- arXiv: https://arxiv.org/abs/2412.12892

### TRACE

- arXiv HTML: https://arxiv.org/html/2503.07982v2

### EFED

- PDF: https://csslab-ustc.github.io/publications/2024/edge-detect.pdf

---

## 11. まとめ

2024〜2026年の画像輪郭線抽出は、単なるエッジ検出精度から、以下の方向へ進んでいる。

- 後処理なしの細い線、crisp edge
- foundation model、SAM、diffusion modelの活用
- Transformer / Mambaによるglobal context利用
- 軽量・高速・省電力化
- 複数アノテータ由来の不確実性や多粒度エッジの扱い

研究目的なら、まず以下を読むのが効率的。

1. MEMO
2. MatchED
3. EasyControlEdge
4. EDMB
5. Taming SAM
6. TRACE

実装・比較目的なら、以下を押さえると良い。

1. Canny / Sobel
2. HED
3. PiDiNet
4. DexiNed
5. EDTER
6. UAED
7. NBED

漫画・イラスト・線画抽出に近い用途では、論文のedge detectionだけでなく、ControlNet系のCanny / LineartプリプロセッサやSAM系の境界補助も比較対象に入れると実用的である。
