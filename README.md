# SSPI_Challenge_Spectrum_2026
This repo contains the submission of the tasks for SSPI challenge


This repository contains implementations for two distinct engineering tasks: an advanced Biomedical Signal Processing pipeline in Python and a scalable Digital System Design module in Verilog.

---

## 1. ECG-Derived Respiration (EDR) & Breathing Rate Estimation

### Problem Overview
This module extracts a **respiration (breathing) signal** from a single-channel ECG and estimates the **Breathing Rate (Breaths per Minute)** using digital signal processing techniques without requiring a dedicated respiratory belt.

###  Dataset Details
* **Source:** MIT-BIH Arrhythmia Database (Record 102)
* **Sampling Frequency ($f_s$):** $360 \text{ Hz}$

###  Methodology & Pipeline
1. **R-Peak Detection:** Detects the R-peaks of the ECG signal using an amplitude threshold and a minimum peak distance constraint ($0.6 \times f_s$) to cleanly isolate individual QRS complexes.
2. **Respiratory Envelope Extraction (EDR):** Extracts the modulation amplitude of the detected R-peaks. A **cubic spline interpolation** is then applied across these peaks to construct the continuous, smooth respiratory envelope.
3. **Low-Pass Filtering:** Passes the raw EDR signal through a **4th-order Butterworth low-pass filter** with a cutoff frequency of $f_c = 0.5 \text{ Hz}$. This attenuates high-frequency muscle artifacts and cardiac noise, preserving the normal human respiratory band ($0.1 \text{ Hz} \le f \le 0.5 \text{ Hz}$).
4. **Rate Calculation:** Identifies the localized peaks of the filtered respiration signal. By calculating the average time interval ($T_{\text{avg}}$) between successive breaths, the final breathing rate is computed as:
   $$\text{Breathing Rate (BPM)} = \frac{60}{T_{\text{avg}}}$$


# 2. Scalable $N \times N$ Systolic Array Matrix Multiplier

##  Project Overview
This project implements a hardware-based matrix multiplier using a highly parallel and pipelined systolic array architecture[cite: 3]. The design computes the matrix multiplication equation $C = C + A \times B$ by streaming data rhythmically through a grid of specialized nodes[cite: 3].

##  Hardware Architecture

### (i) Processing Element (PE)
The core computational block executing the basic Multiply-Accumulate (MAC) operation[cite: 3]:
* **MAC Logic:** $C = C + (A \times B)$[cite: 3].
* **Pipelining:** Inputs `a_in` and `b_in` are registered every clock cycle to output ports `a_out` and `b_out`, enabling clean local data movement between neighboring PEs[cite: 3].

### (ii) Top Module Structure
* **Hierarchy:** Organizes an $N \times N$ grid conforming strictly to automated marking schemes with explicit loop naming: rows as `pe_row[i]`, columns as `pe_col[j]`, and PEs as `u_pe`[cite: 3].
* **Scalability:** Built using Verilog `generate` blocks to smoothly scale from $2 \times 2$ up to $8 \times 8$ dimensions[cite: 3].

---

##  Timing & Pipeline Latency
Inputs must enter skewed to match the internal network delay stages[cite: 3]:
* **Propagation:** Row/Col $(0,0)$ begins at $T=0$, adjacent neighbors receive data at $T=1$, and the diagonal PE $(1,1)$ takes data at $T=2$[cite: 3].
* **Latency Profile:** 
  * **Total clock cycles required:** $2N - 1$[cite: 3].
  * **First output:** Appears after $N$ cycles[cite: 3].
  * **Last output / Done Signal:** Asserted at $2N - 1$ cycles once the complete pipeline flushes[cite: 3].

---

##  Simulation & Verification
Verified using standard HDL simulation environments validating cycle-by-cycle signal accuracy[cite: 3]:
* **Unit Testing:** Validated $2 \times 2$ array multiplication matrix math using small, manual test vector integers[cite: 3].
* **Stress Testing:** Automated verification via a self-checking testbench framework checking array output data matches a golden software reference model[cite: 3].
