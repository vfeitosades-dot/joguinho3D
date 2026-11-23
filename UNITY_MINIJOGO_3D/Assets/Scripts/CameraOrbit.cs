using UnityEngine;

namespace BlocoQuest
{
    [RequireComponent(typeof(Camera))]
    public sealed class CameraOrbit : MonoBehaviour
    {
        public Transform target;
        public float distance = 6.3f;
        public float sensitivity = 3.1f;

        private float yaw = 35f;
        private float pitch = 23f;

        private void LateUpdate()
        {
            if (!target) return;

            if (Input.GetMouseButton(1))
            {
                yaw += Input.GetAxis("Mouse X") * sensitivity;
                pitch -= Input.GetAxis("Mouse Y") * sensitivity;
                pitch = Mathf.Clamp(pitch, -12f, 65f);
            }

            Vector3 focus = target.position + Vector3.up * .1f;
            Quaternion rotation = Quaternion.Euler(pitch, yaw, 0f);
            Vector3 ideal = focus - rotation * Vector3.forward * distance;
            Vector3 path = ideal - focus;
            float d = path.magnitude;
            RaycastHit hit;
            int mask = ~(1 << 2); // player is in Ignore Raycast layer
            if (Physics.SphereCast(focus, .18f, path.normalized, out hit, d,
                                  mask, QueryTriggerInteraction.Ignore))
            {
                ideal = focus + path.normalized * Mathf.Max(.5f, hit.distance - .25f);
            }

            transform.position = Vector3.Lerp(transform.position, ideal,
                1f - Mathf.Exp(-14f * Time.deltaTime));
            transform.LookAt(focus, Vector3.up);
        }
    }
}
