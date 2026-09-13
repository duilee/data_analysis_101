# 9장. MAB(Multi Armed Bandit) 그거 어떻게 쓰는건데…?

이 챕터의 실습 코드입니다. Multi-Armed Bandit 의 **Thompson Sampling**(베이지안·베타 분포)을
시뮬레이션으로 직접 돌려 보며, 실제 서비스(배너 클릭율 최적화)에 적용할 때의 보완 기법까지 다룹니다.

- **실습 1.** 기본 Thompson Sampling — 베타 분포가 수렴하며 최적 배너에 노출이 집중되는 과정
- **실습 2.** AB 테스트 vs MAB — 고정 분할 AB와 누적 regret 비교 (AB의 실험 비용을 수치로)
- **실습 3.** α × Coefficient — 비슷하고 낮은 CTR 배너의 분포를 계수로 분리
- **실습 4.** Discounted Thompson Sampling — 시즈널리티(최적이 바뀌는 환경)에 적응

## 실행 방법

```bash
jupyter notebook mab_thompson_sampling.ipynb   # 노트북을 위에서 아래로 실행 (첫 셀이 의존성 설치)
```

## 파일 구성

| 파일 | 설명 |
| --- | --- |
| `mab_thompson_sampling.ipynb` | 실습 1~4 노트북 (Thompson Sampling 시뮬레이션) |
| `requirements.txt` | 의존성 (numpy, scipy, pandas, matplotlib, jupyter) |

> 이 챕터는 **데이터 파일이 없습니다.** 배너의 '진짜 확률'을 정해 두고 노트북이 직접
> 시뮬레이션을 돌리므로, 알고리즘이 그 확률을 찾아가는 과정을 그대로 관찰할 수 있습니다.
> 시각화 라벨은 영어, 서술은 한국어이며 `np.random.seed(42)` 로 재현됩니다.
