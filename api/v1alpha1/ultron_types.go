/*
Copyright 2024.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package v1alpha1

import (
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

type UltronSpec struct {
	Address     corev1.EndpointAddress     `json:"address"`
	Certificate CertificateSpec            `json:"certificate"`
	Container   corev1.Container           `json:"container"`
	Credentials []corev1.SecretKeySelector `json:"credentials"`
	Redis       RedisSpec                  `json:"redis"`
}

type UltronStatus struct {
}

//+kubebuilder:object:root=true
//+kubebuilder:subresource:status

type Ultron struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   UltronSpec   `json:"spec,omitempty"`
	Status UltronStatus `json:"status,omitempty"`
}

//+kubebuilder:object:root=true

type UltronList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []Ultron `json:"items"`
}

func init() {
	SchemeBuilder.Register(&Ultron{}, &UltronList{})
}
