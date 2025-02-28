using UnityEngine;

public class RaycastSweep : MonoBehaviour
{
    public LayerMask mask;
    public float raycastLength;
    
    private int direction = 1;
    private float angle = 0;

    float m_MaxDistance;
    float m_Speed;
    bool m_HitDetect;

    Collider m_Collider;
    RaycastHit m_Hit;

    private Vector3[] points = new Vector3[2];
    public LineController line;
    public TextManager textManager;
    public SC_FPSController player;

    // Start is called before the first frame update
    void Start()
    {
        m_MaxDistance = 10f;
        m_Speed = 20.0f;
        m_Collider = GetComponent<Collider>();
    }

    // Update is called once per frame
    void Update()
    {
       
        
    }

    private void FixedUpdate()
    {
        m_HitDetect = Physics.BoxCast(m_Collider.bounds.center, transform.localScale * 1f, transform.forward, out m_Hit, transform.rotation, m_MaxDistance, mask);
        if (m_HitDetect)
        {
            
            points[0] = m_Collider.bounds.center;
            points[1] = m_Hit.point;
            line.SetUpLine(points);
            //Output the name of the Collider your Box hit
            if (m_Hit.collider.tag == "Player")
            {
                Debug.Log("Hit : " + m_Hit.collider.name);
                textManager.gameObject.SetActive(true);
                textManager.Reveal();
                player.caught = true;
                transform.parent.GetComponent<NpcControl>().enabled = false;
            }

        }

    }

    void OnDrawGizmos()
    {
        Gizmos.color = Color.red;

        //Check if there has been a hit yet
        if (m_HitDetect)
        {
            //Draw a Ray forward from GameObject toward the hit
            Gizmos.DrawRay(transform.position, transform.forward * m_Hit.distance);
            //Draw a cube that extends to where the hit exists
            Gizmos.DrawWireCube(transform.position + transform.forward * m_Hit.distance, transform.localScale * 1);
        }
        //If there hasn't been a hit yet, draw the ray at the maximum distance
        else
        {
            //Draw a Ray forward from GameObject toward the maximum distance
            Gizmos.DrawRay(transform.position, transform.forward * m_MaxDistance);
            //Draw a cube at the maximum distance
            Gizmos.DrawWireCube(transform.position + transform.forward * m_MaxDistance, transform.localScale * 1);
        }
    }

}
