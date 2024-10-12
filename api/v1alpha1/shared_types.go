package v1alpha1

import corev1 "k8s.io/api/core/v1"

type RedisSpec struct {
	Address  string                 `json:"address"`
	Database int32                  `json:"database"`
	Password corev1.SecretEnvSource `json:"password"`
}
