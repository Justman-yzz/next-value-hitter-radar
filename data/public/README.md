# MLB 공개 시연 데이터 — 라이선스와 출처

`mlb_lahman_2023_2025.csv`와 `mlb_lahman_2023_2025.js`는 **SABR Lahman Baseball Database**를 가공한 데이터입니다.

- **원본:** The SABR Lahman Baseball Database 1871–2025, 2025판(2025-12-10 릴리스) — https://sabr.org/lahman-database/
- **저작권:** Copyright 1996–2025 SABR, via donation from Sean Lahman
- **라이선스:** Creative Commons Attribution-ShareAlike 3.0 Unported (CC BY-SA 3.0) — https://creativecommons.org/licenses/by-sa/3.0/
  - 근거: 원본 배포본 `readme2025.txt` 0.1절 "Copyright Notice & Limited Use License"
- **이 가공 데이터의 라이선스:** 원본과 같은 CC BY-SA 3.0입니다(동일조건변경허락).

## 가공 내용

1. `Batting.csv`(정규시즌 타격 기록, 포스트시즌 제외)에서 2023–2025 시즌만 사용했습니다. 타자 기록 전용입니다.
2. 같은 시즌에 여러 구단에서 뛴 선수는 stint별 기록을 선수-시즌 1행으로 합산했습니다. 구단은 `A→B`처럼 표기합니다.
3. PA = AB + BB + HBP + SH + SF로 계산했습니다. Lahman에는 포수 타격방해(CI) 필드가 없어, MLB 공식 PA보다 CI 횟수(보통 연 0~3회)만큼 적을 수 있습니다.
4. 나이는 `People.csv`의 생년월일로 계산한 6월 30일 기준 만 나이입니다. 이름은 nameFirst + nameLast입니다.
5. 주 포지션은 `Fielding.csv`에서 수비 경기 수가 가장 많은 포지션입니다. 수비 기록이 없으면 DH, 투수 기록이 가장 많지만 100타석 이상이면 P/DH로 표기했습니다.
6. 0타석 행(타석 없는 투수 등)은 제외했습니다.
7. 구단 약어는 `Teams.csv`의 teamIDBR입니다.

재생성 방법: 원본 CSV를 `data/sources/lahman_2025/`에 둔 뒤 `powershell -ExecutionPolicy Bypass -File scripts\build_mlb.ps1`를 실행합니다.

이 데이터는 MLB 사무국의 공식 데이터가 아니며, MLB와 SABR은 이 프로젝트와 관련이 없습니다.
