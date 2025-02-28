using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.AI;

public class NpcControl : MonoBehaviour
{
    public Transform[] navPoints;
    NavMeshAgent agent;
    Transform target;
    int targetIndex = 0;

    // Start is called before the first frame update
    void Start()
    {
        Reset();
        agent = GetComponent<NavMeshAgent>();
        target = navPoints[0];
        navPoints[0].GetComponent<Collider>().enabled = true;
    }

    // Update is called once per frame
    void Update()
    {
        agent.SetDestination(target.position);
    }

    public void SetNewDestination()
    {
        targetIndex += 1;
        if (targetIndex == navPoints.Length)
        {
            targetIndex = 0;
        }
        target = navPoints[targetIndex];
        Reset();
        navPoints[targetIndex].GetComponent<Collider>().enabled = true;
    }


    private void Reset()
    {
        for (int i = 0; i < navPoints.Length; i++)
        {
            navPoints[i].GetComponent<Collider>().enabled = false;
        }
    }
}
