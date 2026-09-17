<div align="center">

<img src="assets/icon.png" width="128" alt="PokeTaskBar 아이콘">

# PokeTaskBar v1

**Linear 일과 점수가 중심입니다. 토큰 사용량은 옆자리이고, XP로 바뀝니다.**

[English](README.md) · **한국어** · [日本語](README.ja.md)

</div>

PokeTaskBar v1은 [spawnaudio/spawn-PokeTokenBar](https://github.com/spawnaudio/spawn-PokeTokenBar) (PokeTokenBar v3)에서 갈라진 **새 macOS 앱**입니다. v3를 이름만 바꾼 것이 아닙니다.

정본은 **[영어 README](README.md)** 입니다.

| | PokeTokenBar v3 (그대로) | **PokeTaskBar v1** |
|---|---|---|
| 표시 이름 | `PokeTokenBar v3` | **`PokeTaskBar v1`** |
| Bundle id | `io.github.chattymin.poketokenbar.v3` | **`io.github.spawnaudio.poketaskbar.v1`** |
| 앱 | `/Applications/PokeTokenBar v3.app` | `/Applications/PokeTaskBar v1.app` |
| 세이브 | `~/Library/Application Support/PokeTokenBar v3` | `~/Library/Application Support/PokeTaskBar v1` |
| 재빌드 | `./scripts/rebuild-v3.sh` | **`./scripts/rebuild-v1.sh`** |

- Linear 이슈·프로젝트·Focus·Today가 메인 루프
- 토큰 사용은 1:1 XP. **Token usage** 페이지만 Tokens, 나머지는 XP
- `Coins = floor(XP / 1000)`. 상점은 **Requires N Coins**
- 민트는 30분 XP 2배 (성격 리롤 아님)
- 알은 보관함. 사도 현재 포켓몬을 놓아주지 않음. 한 마리만 육성, 언제든 교체
- 졸업 포켓몬은 육성 불가, 도감에 트로피

원본 제품 설명은 [`Documents/original-PokeTokenBar/README.ko.md`](Documents/original-PokeTokenBar/README.ko.md)에 있습니다. 라이선스·면책은 [영어 README](README.md#license--disclaimer)를 따릅니다.
