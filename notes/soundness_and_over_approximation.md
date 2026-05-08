---
title: Soundness and overapproximation
author: Yuxiang Wei
date: Aug 29, 2022
---

The specification and overapproximation

$$
\mathbb{Y} \doteq \{f(x) \mid x \in \mathbf X\}\\
\mathit{spec}: \mathbb Y\subseteq \mathbf Y\\
\mathit{spec'}: \mathcal Y \subseteq \mathbf Y, \text{where } \mathbb Y \subseteq \mathcal Y\ (\text{overapproximation})\\
% \mathit{verify}: (\mathit{spec}) \to \mathbf{bool}\\
% Y' \supseteq Y\\
$$

Easy to prove
$$
\text{If }\mathit{spec'} \text{ holds then } \mathit{spec} \text{ holds}
$$

Sound means

$$
\text{If }\mathit{spec}\text{ is verified} \text{ then } \mathit{spec}\ \text{holds}
$$

Due to overapproximation, if verifying $\textit{spec'}$ is sound we have
$$
\text{If }\mathit{spec'}\text{ is verified then } \mathit{spec'} \text{ holds}
$$

We want to prove that if we can construct a verifier for $\mathit{spec'}$, we can always construct one for $\mathit{spec}$. The code below shows this property: as long as `verify'` is sound, `verify` is sound.

```haskell
-- A sound verifier for spec'
verify' :: Spec -> Bool
...

-- A sound verifier for spec
verify :: Spec -> Bool
verify spec = let spec' = overapprox spec in verify' spec'
```
