ARG VLLM_TAG=latest
FROM vllm/vllm-openai:${VLLM_TAG}

RUN VLLM_VERSION="$(pip show vllm | sed -n 's/^Version: //p')" \
    && pip install --no-cache-dir --ignore-installed --no-deps blinker \
    && pip install --no-cache-dir "vllm[audio]==${VLLM_VERSION}"
