#ifndef LILIUM_CLUSTER_LIGHT_LOOP_COMPAT_INCLUDED
#define LILIUM_CLUSTER_LIGHT_LOOP_COMPAT_INCLUDED

// URP 6.1 (17.1) で Forward+ のマクロが改名された。
//   _FORWARD_PLUS                        -> _CLUSTER_LIGHT_LOOP
//   USE_FORWARD_PLUS                     -> USE_CLUSTER_LIGHT_LOOP
//   FORWARD_PLUS_SUBTRACTIVE_LIGHT_CHECK -> CLUSTER_LIGHT_LOOP_SUBTRACTIVE_LIGHT_CHECK
//
// URP 側の後方互換(ForwardPlusKeyword.deprecated.hlsl)は「シェーダーが _FORWARD_PLUS キーワードを
// 宣言している場合だけ」旧名を定義する。ShaderGraph が新しい _CLUSTER_LIGHT_LOOP を宣言する 6.1 以降では
// USE_FORWARD_PLUS が未定義になり、旧名のままの #if USE_FORWARD_PLUS が常に false になる。
// すると Forward+ で追加のディレクショナルライトを回すループごと消え、
// メインライト以外のディレクショナルライトが当たらなくなる。
//
// ここでは新しい名前に寄せたうえで、旧 URP(6.0 以前)でも動くよう旧名から補う。
// どちらも無い URP では未定義のまま = #if で 0 に評価されるので、Forward+ ではない扱いになる。
#if !defined(USE_CLUSTER_LIGHT_LOOP) && defined(USE_FORWARD_PLUS)
    #define USE_CLUSTER_LIGHT_LOOP USE_FORWARD_PLUS

    #if !defined(CLUSTER_LIGHT_LOOP_SUBTRACTIVE_LIGHT_CHECK) && defined(FORWARD_PLUS_SUBTRACTIVE_LIGHT_CHECK)
        #define CLUSTER_LIGHT_LOOP_SUBTRACTIVE_LIGHT_CHECK FORWARD_PLUS_SUBTRACTIVE_LIGHT_CHECK
    #endif
#endif

#endif
