"""Teach SGLang to load the nvidia Qwen3.8-Flash-Next-FP4-Local checkpoint.

That repo keeps its safetensors shards under ``tensors/`` while SGLang's
default loader only globs the snapshot root, so weight discovery dies with
"Cannot find any model weights". SGLang already supports subfolder
checkpoints via the model-class attribute ``allow_patterns_overrides``
(Cosmos3 uses it for ``transformer/``); Qwen4-Exp simply never sets it.
This hook sets it when the model module is imported. It is mounted over
site-packages/sitecustomize.py so it runs in every interpreter process,
including spawned TP and speculative-draft workers.
"""

import importlib.util
import sys

_TARGET_MODULE = "sglang.srt.models.qwen4_exp"
_TENSORS_PATTERN = ["tensors/*.safetensors"]
_PATCHED_CLASSES = ("Qwen4ExpForConditionalGeneration", "Qwen4ExpModel")


class _TensorsLayoutFinder:
    def find_spec(self, fullname, path=None, target=None):
        if fullname != _TARGET_MODULE:
            return None
        sys.meta_path.remove(self)
        try:
            spec = importlib.util.find_spec(fullname)
        except (ImportError, ValueError):
            return None
        finally:
            sys.meta_path.insert(0, self)
        if spec is None or spec.loader is None:
            return None
        original_exec_module = spec.loader.exec_module

        def exec_module(module):
            original_exec_module(module)
            for class_name in _PATCHED_CLASSES:
                model_class = getattr(module, class_name, None)
                if model_class is not None:
                    model_class.allow_patterns_overrides = _TENSORS_PATTERN

        spec.loader.exec_module = exec_module
        return spec


sys.meta_path.insert(0, _TensorsLayoutFinder())