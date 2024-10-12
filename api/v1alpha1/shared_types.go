package v1alpha1

import corev1 "k8s.io/api/core/v1"

type RedisSpec struct {
	Address  corev1.EndpointAddress `json:"address"`
	Password corev1.EnvVar          `json:"password"`
	Database int32                  `json:"database"`
}

type CertificateSpec struct {
	CommonName   string `json:"commonName"`
	DnsNames     string `json:"dnsNames"`
	ExportPath   string `json:"exportPath"`
	IpAddresses  string `json:"ipAddresses"`
	Organization string `json:"organization"`
}
